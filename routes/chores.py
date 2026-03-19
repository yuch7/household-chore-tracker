from datetime import date, datetime, timedelta
from flask import Blueprint, render_template, request, jsonify, redirect, url_for
from flask_login import login_required
from extensions import db
from models import Task, ChoreLog, CalendarEvent
from services import get_date_range

chores_bp = Blueprint('chores', __name__)


@chores_bp.route('/')
@login_required
def index():
    tasks = Task.query.all()
    logs = ChoreLog.query.all()

    total_balance = 0
    for log in logs:
        if log.user_name == "Yuch":
            total_balance -= log.reward_at_time
        else:
            total_balance += log.reward_at_time

    return render_template('index.html', tasks=tasks, total_budget=total_balance)


@chores_bp.route('/manage')
@login_required
def manage():
    tasks = Task.query.all()
    return render_template('manage.html', tasks=tasks)


@chores_bp.route('/history')
@login_required
def history():
    page = request.args.get('page', 1, type=int)
    per_page = 50

    pagination = ChoreLog.query.order_by(
        ChoreLog.date_completed.desc(),
        ChoreLog.id.desc()
    ).paginate(page=page, per_page=per_page, error_out=False)

    logs = pagination.items

    all_logs = ChoreLog.query.all()
    alice_total = sum(l.reward_at_time for l in all_logs if l.user_name == "Maggie")
    bob_total = sum(l.reward_at_time for l in all_logs if l.user_name == "Yuch")

    return render_template('history.html',
                           logs=logs,
                           pagination=pagination,
                           alice_total=alice_total,
                           bob_total=bob_total)


@chores_bp.route('/add_task', methods=['POST'])
@login_required
def add_task():
    db.session.add(Task(
        name=request.form.get('name'),
        reward=float(request.form.get('reward')),
        limit_count=int(request.form.get('limit')),
        interval=request.form.get('interval')
    ))
    db.session.commit()
    return redirect(url_for('chores.manage'))


@chores_bp.route('/delete_task/<int:id>')
@login_required
def delete_task(id):
    Task.query.filter_by(id=id).delete()
    db.session.commit()
    return redirect(url_for('chores.manage'))


@chores_bp.route('/add_chore', methods=['POST'])
@login_required
def add_chore():
    task = Task.query.get(request.form.get('task_id'))
    user = request.form.get('user')
    today = date.today()

    user_color = "#007bff" if user == "Yuch" else "#dc3545"

    start_date, end_date = get_date_range(task.interval, today)

    count = ChoreLog.query.filter(
        ChoreLog.task_name == task.name,
        ChoreLog.date_completed >= start_date,
        ChoreLog.date_completed <= end_date
    ).count()

    if count < task.limit_count:
        db.session.add(ChoreLog(
            user_name=user, task_name=task.name,
            reward_at_time=task.reward, color_at_time=user_color,
            date_completed=today
        ))
        db.session.commit()
    return redirect(url_for('chores.index'))


@chores_bp.route('/add_custom_chore', methods=['POST'])
@login_required
def add_custom_chore():
    user = request.form.get('user')
    user_color = "#007bff" if user == "Yuch" else "#dc3545"

    db.session.add(ChoreLog(
        user_name=user, task_name=f"Custom: {request.form.get('custom_name')}",
        reward_at_time=float(request.form.get('custom_amount')),
        color_at_time=user_color, date_completed=date.today()
    ))
    db.session.commit()
    return redirect(url_for('chores.index'))


@chores_bp.route('/add_event', methods=['POST'])
@login_required
def add_event():
    title = request.form.get('event_title')
    event_date = datetime.strptime(request.form.get('event_date'), '%Y-%m-%d').date()
    color = request.form.get('event_color', '#28a745')

    start_time = None
    duration_minutes = None
    time_str = request.form.get('event_time')
    if time_str:
        start_time = datetime.strptime(time_str, '%H:%M').time()
        duration_minutes = int(request.form.get('event_duration', 60))

    db.session.add(CalendarEvent(
        title=title,
        event_date=event_date,
        start_time=start_time,
        duration_minutes=duration_minutes,
        color=color
    ))
    db.session.commit()
    return redirect(url_for('chores.index'))


@chores_bp.route('/api/event/<int:id>')
@login_required
def get_event(id):
    e = CalendarEvent.query.get_or_404(id)
    return jsonify({
        'id': e.id,
        'title': e.title,
        'event_date': e.event_date.isoformat(),
        'start_time': e.start_time.strftime('%H:%M') if e.start_time else '',
        'duration_minutes': e.duration_minutes or 60,
        'color': e.color
    })


@chores_bp.route('/api/event/<int:id>', methods=['PUT'])
@login_required
def update_event(id):
    e = CalendarEvent.query.get_or_404(id)
    data = request.json
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


@chores_bp.route('/api/delete_event/<int:id>', methods=['DELETE'])
@login_required
def delete_event(id):
    CalendarEvent.query.filter_by(id=id).delete()
    db.session.commit()
    return jsonify({'status': 'success'})


@chores_bp.route('/api/events')
@login_required
def events():
    start = request.args.get('start')
    end = request.args.get('end')

    # Chore events
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
            'backgroundColor': color, 'borderColor': color,
            'textColor': '#ffffff', 'editable': True,
            'extendedProps': {'type': 'chore', 'dbId': l.id}
        })

    # Calendar events
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
            'backgroundColor': e.color, 'borderColor': e.color,
            'textColor': '#ffffff', 'editable': False,
            'extendedProps': {'type': 'event', 'dbId': e.id}
        }
        if e.start_time:
            start_dt = datetime.combine(e.event_date, e.start_time)
            end_dt = start_dt + timedelta(minutes=e.duration_minutes or 60)
            evt['start'] = start_dt.isoformat()
            evt['end'] = end_dt.isoformat()
        else:
            evt['start'] = e.event_date.isoformat()
            evt['allDay'] = True

        event_list.append(evt)

    return jsonify(event_list)


@chores_bp.route('/api/move_chore', methods=['POST'])
@login_required
def move_chore():
    data = request.json
    raw_id = str(data.get('id'))
    chore_id = int(raw_id.replace('chore_', ''))
    log = ChoreLog.query.get(chore_id)
    new_date = datetime.strptime(data.get('start'), '%Y-%m-%d').date()

    if log.task_name.startswith("Custom:"):
        log.date_completed = new_date
        db.session.commit()
        return jsonify({'status': 'success'})

    task = Task.query.filter_by(name=log.task_name).first()
    if task:
        start_date, end_date = get_date_range(task.interval, new_date)

        count = ChoreLog.query.filter(
            ChoreLog.task_name == task.name,
            ChoreLog.date_completed >= start_date,
            ChoreLog.date_completed <= end_date,
            ChoreLog.id != log.id
        ).count()

        if count >= task.limit_count:
            return jsonify({'status': 'error'}), 400

    log.date_completed = new_date
    db.session.commit()
    return jsonify({'status': 'success'})


@chores_bp.route('/api/delete_log/<int:id>', methods=['DELETE'])
@login_required
def delete_log(id):
    ChoreLog.query.filter_by(id=id).delete()
    db.session.commit()
    return jsonify({'status': 'success'})
