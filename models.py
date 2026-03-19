from datetime import date, datetime
from flask_login import UserMixin
from extensions import db


class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(100), unique=True, nullable=False)


class Task(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    reward = db.Column(db.Float, nullable=False)
    limit_count = db.Column(db.Integer, default=1)
    interval = db.Column(db.String(10), default='weekly')


class ChoreLog(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_name = db.Column(db.String(50), nullable=False, index=True)
    task_name = db.Column(db.String(100), index=True)
    reward_at_time = db.Column(db.Float)
    color_at_time = db.Column(db.String(20))
    date_completed = db.Column(db.Date, default=date.today, index=True)


class CalendarEvent(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    event_date = db.Column(db.Date, nullable=False, index=True)
    start_time = db.Column(db.Time, nullable=True)
    duration_minutes = db.Column(db.Integer, nullable=True)
    color = db.Column(db.String(20), default='#28a745')


class Transaction(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    currency = db.Column(db.String(3), nullable=False, index=True)
    user = db.Column(db.String(50))
    description = db.Column(db.String(100))
    amount = db.Column(db.Float)
    timestamp = db.Column(db.DateTime, default=datetime.now)
