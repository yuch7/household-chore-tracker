import os
import secrets
from datetime import date, datetime, timedelta
from functools import wraps

from flask import Blueprint, request, jsonify
from google.oauth2 import id_token
from google.auth.transport import requests as google_requests
from sqlalchemy import func

from extensions import db
from models import User, ApiToken, Task, ChoreLog, CalendarEvent, Transaction
from services import get_date_range

api_bp = Blueprint('api', __name__, url_prefix='/api')

WHITELIST = ["yuchen7990@gmail.com", "maggiezhuu@gmail.com"]


def api_auth_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return jsonify({'error': 'Missing or invalid Authorization header'}), 401
        token_str = auth_header[7:]
        api_token = ApiToken.query.filter_by(token=token_str).first()
        if not api_token:
            return jsonify({'error': 'Invalid token'}), 401
        request.api_user = api_token.user
        return f(*args, **kwargs)
    return decorated


# --- Auth ---

@api_bp.route('/auth/google', methods=['POST'])
def auth_google():
    data = request.get_json()
    id_token_str = data.get('id_token')
    if not id_token_str:
        return jsonify({'error': 'id_token required'}), 400

    try:
        client_id = os.environ["GOOGLE_CLIENT_ID"]
        idinfo = id_token.verify_oauth2_token(
            id_token_str, google_requests.Request(), client_id
        )
        email = idinfo['email']
    except Exception as e:
        return jsonify({'error': f'Invalid token: {str(e)}'}), 401

    if email not in WHITELIST:
        return jsonify({'error': 'Email not whitelisted'}), 403

    user = User.query.filter_by(email=email).first()
    if not user:
        user = User(email=email)
        db.session.add(user)
        db.session.commit()

    token_str = secrets.token_hex(32)
    api_token = ApiToken(user_id=user.id, token=token_str)
    db.session.add(api_token)
    db.session.commit()

    return jsonify({'token': token_str, 'email': email})


# --- Balance ---

@api_bp.route('/balance')
@api_auth_required
def get_balance():
    logs = ChoreLog.query.all()
    maggie_total = sum(l.reward_at_time for l in logs if l.user_name == "Maggie")
    yuch_total = sum(l.reward_at_time for l in logs if l.user_name == "Yuch")
    balance = maggie_total - yuch_total
    return jsonify({
        'balance': balance,
        'maggie_total': maggie_total,
        'yuch_total': yuch_total
    })


# --- Tasks ---

@api_bp.route('/tasks')
@api_auth_required
def list_tasks():
    tasks = Task.query.all()
    return jsonify([{
        'id': t.id,
        'name': t.name,
        'reward': t.reward,
        'limit_count': t.limit_count,
        'interval': t.interval
    } for t in tasks])


@api_bp.route('/tasks', methods=['POST'])
@api_auth_required
def create_task():
    data = request.get_json()
    task = Task(
        name=data['name'],
        reward=float(data['reward']),
        limit_count=int(data.get('limit_count', 1)),
        interval=data.get('interval', 'weekly')
    )
    db.session.add(task)
    db.session.commit()
    return jsonify({
        'id': task.id,
        'name': task.name,
        'reward': task.reward,
        'limit_count': task.limit_count,
        'interval': task.interval
    }), 201


@api_bp.route('/tasks/<int:id>', methods=['DELETE'])
@api_auth_required
def delete_task(id):
    task = Task.query.get_or_404(id)
    db.session.delete(task)
    db.session.commit()
    return jsonify({'status': 'success'})


# --- Chores ---

@api_bp.route('/chores', methods=['POST'])
@api_auth_required
def log_chore():
    data = request.get_json()
    task = Task.query.get_or_404(data['task_id'])
    user = data['user']
    chore_date = date.today()
    if data.get('date'):
        chore_date = datetime.strptime(data['date'], '%Y-%m-%d').date()

    user_color = "#007bff" if user == "Yuch" else "#dc3545"
    start_date, end_date = get_date_range(task.interval, chore_date)

    count = ChoreLog.query.filter(
        ChoreLog.task_name == task.name,
        ChoreLog.date_completed >= start_date,
        ChoreLog.date_completed <= end_date
    ).count()

    if count >= task.limit_count:
        return jsonify({'error': 'Limit reached for this interval'}), 409

    log = ChoreLog(
        user_name=user, task_name=task.name,
        reward_at_time=task.reward, color_at_time=user_color,
        date_completed=chore_date
    )
    db.session.add(log)
    db.session.commit()
    return jsonify({
        'id': log.id,
        'user_name': log.user_name,
        'task_name': log.task_name,
        'reward_at_time': log.reward_at_time,
        'date_completed': log.date_completed.isoformat()
    }), 201


@api_bp.route('/chores/custom', methods=['POST'])
@api_auth_required
def log_custom_chore():
    data = request.get_json()
    user = data['user']
    user_color = "#007bff" if user == "Yuch" else "#dc3545"

    log = ChoreLog(
        user_name=user,
        task_name=f"Custom: {data['name']}",
        reward_at_time=float(data['amount']),
        color_at_time=user_color,
        date_completed=date.today()
    )
    db.session.add(log)
    db.session.commit()
    return jsonify({
        'id': log.id,
        'user_name': log.user_name,
        'task_name': log.task_name,
        'reward_at_time': log.reward_at_time,
        'date_completed': log.date_completed.isoformat()
    }), 201


@api_bp.route('/history')
@api_auth_required
def chore_history():
    page = request.args.get('page', 1, type=int)
    per_page = 50

    pagination = ChoreLog.query.order_by(
        ChoreLog.date_completed.desc(),
        ChoreLog.id.desc()
    ).paginate(page=page, per_page=per_page, error_out=False)

    return jsonify({
        'items': [{
            'id': l.id,
            'user_name': l.user_name,
            'task_name': l.task_name,
            'reward_at_time': l.reward_at_time,
            'date_completed': l.date_completed.isoformat()
        } for l in pagination.items],
        'page': pagination.page,
        'pages': pagination.pages,
        'total': pagination.total
    })


# --- Calendar Events ---

@api_bp.route('/events')
@api_auth_required
def list_events():
    start = request.args.get('start')
    end = request.args.get('end')

    query = ChoreLog.query
    if start and end:
        query = query.filter(
            ChoreLog.date_completed >= start,
            ChoreLog.date_completed <= end
        )

    logs = query.all()
    event_list = []
    for l in logs:
        prefix = "-" if l.user_name == "Yuch" else "+"
        color = "#007bff" if l.user_name == "Yuch" else "#dc3545"
        event_list.append({
            'id': f'chore_{l.id}',
            'title': f"{l.task_name} ({prefix}${l.reward_at_time})",
            'start': l.date_completed.isoformat(),
            'backgroundColor': color,
            'type': 'chore',
            'dbId': l.id
        })

    eq = CalendarEvent.query
    if start and end:
        eq = eq.filter(
            CalendarEvent.event_date >= start,
            CalendarEvent.event_date <= end
        )

    for e in eq.all():
        evt = {
            'id': f'event_{e.id}',
            'title': e.title,
            'event_date': e.event_date.isoformat(),
            'color': e.color,
            'type': 'event',
            'dbId': e.id,
            'start_time': e.start_time.strftime('%H:%M') if e.start_time else None,
            'duration_minutes': e.duration_minutes
        }
        event_list.append(evt)

    return jsonify(event_list)


@api_bp.route('/events', methods=['POST'])
@api_auth_required
def create_event():
    data = request.get_json()
    event_date = datetime.strptime(data['event_date'], '%Y-%m-%d').date()
    color = data.get('color', '#28a745')

    start_time = None
    duration_minutes = None
    if data.get('start_time'):
        start_time = datetime.strptime(data['start_time'], '%H:%M').time()
        duration_minutes = int(data.get('duration_minutes', 60))

    event = CalendarEvent(
        title=data['title'],
        event_date=event_date,
        start_time=start_time,
        duration_minutes=duration_minutes,
        color=color
    )
    db.session.add(event)
    db.session.commit()
    return jsonify({
        'id': event.id,
        'title': event.title,
        'event_date': event.event_date.isoformat(),
        'start_time': event.start_time.strftime('%H:%M') if event.start_time else None,
        'duration_minutes': event.duration_minutes,
        'color': event.color
    }), 201


@api_bp.route('/events/<int:id>')
@api_auth_required
def get_event(id):
    e = CalendarEvent.query.get_or_404(id)
    return jsonify({
        'id': e.id,
        'title': e.title,
        'event_date': e.event_date.isoformat(),
        'start_time': e.start_time.strftime('%H:%M') if e.start_time else None,
        'duration_minutes': e.duration_minutes or 60,
        'color': e.color
    })


@api_bp.route('/events/<int:id>', methods=['PUT'])
@api_auth_required
def update_event(id):
    e = CalendarEvent.query.get_or_404(id)
    data = request.get_json()
    e.title = data.get('title', e.title)
    e.event_date = datetime.strptime(data['event_date'], '%Y-%m-%d').date()
    e.color = data.get('color', e.color)

    time_str = data.get('start_time')
    if time_str:
        e.start_time = datetime.strptime(time_str, '%H:%M').time()
        e.duration_minutes = int(data.get('duration_minutes', 60))
    else:
        e.start_time = None
        e.duration_minutes = None

    db.session.commit()
    return jsonify({'status': 'success'})


@api_bp.route('/events/<int:id>', methods=['DELETE'])
@api_auth_required
def delete_event(id):
    CalendarEvent.query.filter_by(id=id).delete()
    db.session.commit()
    return jsonify({'status': 'success'})


# --- Ledger ---

@api_bp.route('/ledger/<currency>')
@api_auth_required
def get_ledger(currency):
    currency = currency.upper()
    txs = Transaction.query.filter_by(currency=currency).order_by(
        Transaction.timestamp.desc()
    ).all()
    total = db.session.query(func.sum(Transaction.amount)).filter_by(
        currency=currency
    ).scalar() or 0

    return jsonify({
        'currency': currency,
        'total': total,
        'transactions': [{
            'id': t.id,
            'user': t.user,
            'description': t.description,
            'amount': t.amount,
            'timestamp': t.timestamp.isoformat()
        } for t in txs]
    })


@api_bp.route('/ledger/<currency>', methods=['POST'])
@api_auth_required
def add_transaction(currency):
    data = request.get_json()
    amount = float(data['amount'])
    if data.get('type') == 'subtract':
        amount = -amount

    tx = Transaction(
        currency=currency.upper(),
        user=data.get('user'),
        description=data.get('description'),
        amount=amount
    )
    db.session.add(tx)
    db.session.commit()
    return jsonify({
        'id': tx.id,
        'currency': tx.currency,
        'user': tx.user,
        'description': tx.description,
        'amount': tx.amount,
        'timestamp': tx.timestamp.isoformat()
    }), 201


@api_bp.route('/ledger/<currency>/<int:id>', methods=['DELETE'])
@api_auth_required
def delete_transaction(currency, id):
    Transaction.query.filter_by(id=id, currency=currency.upper()).delete()
    db.session.commit()
    return jsonify({'status': 'success'})
