import os
import calendar
from datetime import datetime, timedelta, date
from flask import Flask, render_template, request, jsonify, redirect, url_for, session
from flask_sqlalchemy import SQLAlchemy
from sqlalchemy import func
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
from authlib.integrations.flask_client import OAuth
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)

# --- CONFIGURATION ---
app.secret_key = os.environ["SECRET_KEY"]
GOOGLE_CLIENT_ID = os.environ["GOOGLE_CLIENT_ID"]
GOOGLE_CLIENT_SECRET = os.environ["GOOGLE_CLIENT_SECRET"]

# The list of emails allowed to access your website
WHITELIST = ["yuchen7990@gmail.com", "maggiezhuu@gmail.com"]

# PERSISTENCE: Use the /app/instance folder for Docker volume mapping
db_path = '/app/instance/chores.db'
app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{db_path}'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

# --- LOGIN & OAUTH SETUP ---
login_manager = LoginManager(app)
login_manager.login_view = 'login_page'

oauth = OAuth(app)
google = oauth.register(
    name='google',
    client_id=GOOGLE_CLIENT_ID,
    client_secret=GOOGLE_CLIENT_SECRET,
    server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
    client_kwargs={'scope': 'openid email profile'}
)

# --- DATABASE MODELS ---

class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(100), unique=True, nullable=False)

class Task(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    reward = db.Column(db.Float, nullable=False)
    limit_count = db.Column(db.Integer, default=1)
    interval = db.Column(db.String(10), default='weekly') # 'daily' or 'weekly'

class ChoreLog(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_name = db.Column(db.String(50), nullable=False)
    task_name = db.Column(db.String(100))
    reward_at_time = db.Column(db.Float)
    color_at_time = db.Column(db.String(20))
    date_completed = db.Column(db.Date, default=date.today)

def get_date_range(interval, target_date):
    """Returns the (start_date, end_date) range for a given interval and target date."""
    if interval == 'daily':
        return target_date, target_date
    elif interval == 'weekly':
        # Find the previous Sunday (or today if it is Sunday)
        # Python's weekday(): Mon=0, Sun=6
        # (weekday + 1) % 7 gives: Sun=0, Mon=1... Sat=6
        days_since_sunday = (target_date.weekday() + 1) % 7
        start_date = target_date - timedelta(days=days_since_sunday)
        end_date = start_date + timedelta(days=6)
        return start_date, end_date
    elif interval == 'monthly':
        start_date = target_date.replace(day=1)
        # Get the last day of the month (e.g. 28, 30, 31)
        _, last_day = calendar.monthrange(target_date.year, target_date.month)
        end_date = target_date.replace(day=last_day)
        return start_date, end_date
    
    # Default fallback (should not happen)
    return target_date, target_date

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

# Initialize database
with app.app_context():
    if not os.path.exists('/app/instance'):
        os.makedirs('/app/instance')
    db.create_all()

# --- NEW MODELS ---
class USDTransaction(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user = db.Column(db.String(50))
    description = db.Column(db.String(100))
    amount = db.Column(db.Float) # Positive for deposit, Negative for withdrawal
    timestamp = db.Column(db.DateTime, default=datetime.now)

class CADTransaction(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user = db.Column(db.String(50))
    description = db.Column(db.String(100))
    amount = db.Column(db.Float)
    timestamp = db.Column(db.DateTime, default=datetime.now)



# --- AUTH ROUTES ---

@app.route('/login_page')
def login_page():
    if current_user.is_authenticated:
        return redirect(url_for('index'))
    return render_template('login.html')

@app.route('/login')
def login():
    redirect_uri = url_for('auth', _external=True)
    return google.authorize_redirect(redirect_uri)

@app.route('/auth')
def auth():
    token = google.authorize_access_token()
    user_info = token.get('userinfo')
    email = user_info['email']

    if email in WHITELIST:
        user = User.query.filter_by(email=email).first()
        if not user:
            user = User(email=email)
            db.session.add(user)
            db.session.commit()
        login_user(user)
        return redirect(url_for('index'))
    else:
        return "Access Denied: Email not whitelisted.", 403

@app.route('/logout')
def logout():
    logout_user()
    return redirect(url_for('login_page'))

# --- MAIN ROUTES ---

@app.route('/')
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

@app.route('/manage')
@login_required
def manage():
    tasks = Task.query.all()
    return render_template('manage.html', tasks=tasks)

@app.route('/history')
@login_required
def history():
    page = request.args.get('page', 1, type=int)
    per_page = 50

    # Use paginate instead of .all()
    # error_out=False ensures that if a user goes to a page that doesn't exist, it just returns empty
    pagination = ChoreLog.query.order_by(
        ChoreLog.date_completed.desc(),
        ChoreLog.id.desc()
    ).paginate(page=page, per_page=per_page, error_out=False)

    logs = pagination.items

    # Totals are still calculated based on ALL history for the summary cards
    all_logs = ChoreLog.query.all()
    alice_total = sum(l.reward_at_time for l in all_logs if l.user_name == "Maggie")
    bob_total = sum(l.reward_at_time for l in all_logs if l.user_name == "Yuch")

    return render_template('history.html',
                           logs=logs,
                           pagination=pagination,
                           alice_total=alice_total,
                           bob_total=bob_total)

# --- API & CRUD ROUTES ---

@app.route('/add_task', methods=['POST'])
@login_required
def add_task():
    db.session.add(Task(
        name=request.form.get('name'),
        reward=float(request.form.get('reward')),
        limit_count=int(request.form.get('limit')),
        interval=request.form.get('interval')
    ))
    db.session.commit()
    return redirect(url_for('manage'))

@app.route('/delete_task/<int:id>')
@login_required
def delete_task(id):
    Task.query.filter_by(id=id).delete()
    db.session.commit()
    return redirect(url_for('manage'))

@app.route('/add_chore', methods=['POST'])
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
    return redirect(url_for('index'))

@app.route('/add_custom_chore', methods=['POST'])
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
    return redirect(url_for('index'))

@app.route('/api/events')
@login_required
def events():
    logs = ChoreLog.query.all()
    event_list = []
    for l in logs:
        prefix = "-" if l.user_name == "Yuch" else "+"
        color = "#007bff" if l.user_name == "Yuch" else "#dc3545"
        event_list.append({
            'id': l.id,
            'title': f"{l.task_name} ({prefix}${l.reward_at_time})",
            'start': l.date_completed.isoformat(),
            'backgroundColor': color, 'borderColor': color,
            'textColor': '#ffffff', 'editable': True
        })
    return jsonify(event_list)

@app.route('/api/move_chore', methods=['POST'])
@login_required
def move_chore():
    data = request.json
    log = ChoreLog.query.get(data.get('id'))
    new_date = datetime.strptime(data.get('start'), '%Y-%m-%d').date()
    
    # Check: Allow custom chores to move freely
    if log.task_name.startswith("Custom:"):
        log.date_completed = new_date
        db.session.commit()
        return jsonify({'status': 'success'})

    # Limit check for standard chores
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

@app.route('/api/delete_log/<int:id>', methods=['DELETE'])
@login_required
def delete_log(id):
    ChoreLog.query.filter_by(id=id).delete()
    db.session.commit()
    return jsonify({'status': 'success'})

@app.route('/ledger')
@login_required
def ledger():
    # Fetch all transactions (newest first)
    usd_txs = USDTransaction.query.order_by(USDTransaction.timestamp.desc()).all()
    cad_txs = CADTransaction.query.order_by(CADTransaction.timestamp.desc()).all()
    
    # Calculate Totals using SQL for speed
    usd_total = db.session.query(func.sum(USDTransaction.amount)).scalar() or 0
    cad_total = db.session.query(func.sum(CADTransaction.amount)).scalar() or 0
    
    return render_template('ledger.html', 
                           usd_txs=usd_txs, usd_total=usd_total,
                           cad_txs=cad_txs, cad_total=cad_total)

@app.route('/add_fund/<currency>', methods=['POST'])
@login_required
def add_fund(currency):
    user = request.form.get('user')
    desc = request.form.get('description')
    amount = float(request.form.get('amount'))
    type_ = request.form.get('type') 
    
    final_amount = amount if type_ == 'add' else -amount
    
    if currency == 'USD':
        db.session.add(USDTransaction(user=user, description=desc, amount=final_amount))
    else:
        db.session.add(CADTransaction(user=user, description=desc, amount=final_amount))
        
    db.session.commit()
    return redirect(url_for('ledger'))

@app.route('/delete_fund/<currency>/<int:id>')
@login_required
def delete_fund(currency, id):
    if currency == 'USD':
        USDTransaction.query.filter_by(id=id).delete()
    else:
        CADTransaction.query.filter_by(id=id).delete()
    db.session.commit()
    return redirect(url_for('ledger'))

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(host='0.0.0.0', port=7990)
