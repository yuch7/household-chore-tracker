from flask import Blueprint, redirect, url_for, render_template
from flask_login import login_user, logout_user, current_user
from extensions import db, oauth
from models import User

auth_bp = Blueprint('auth', __name__)

WHITELIST = ["yuchen7990@gmail.com", "maggiezhuu@gmail.com"]


@auth_bp.route('/login_page')
def login_page():
    if current_user.is_authenticated:
        return redirect(url_for('chores.index'))
    return render_template('login.html')


@auth_bp.route('/login')
def login():
    google = oauth.create_client('google')
    redirect_uri = url_for('auth.auth_callback', _external=True)
    return google.authorize_redirect(redirect_uri)


@auth_bp.route('/auth')
def auth_callback():
    google = oauth.create_client('google')
    token = google.authorize_access_token()
    user_info = token.get('userinfo')
    email = user_info['email']

    if email not in WHITELIST:
        return "Access Denied: Email not whitelisted.", 403

    user = User.query.filter_by(email=email).first()
    if not user:
        user = User(email=email)
        db.session.add(user)
        db.session.commit()
    login_user(user)
    return redirect(url_for('chores.index'))


@auth_bp.route('/logout')
def logout():
    logout_user()
    return redirect(url_for('auth.login_page'))
