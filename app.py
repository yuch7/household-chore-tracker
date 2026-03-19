import os
from flask import Flask
from dotenv import load_dotenv
from extensions import db, login_manager, csrf, oauth
from models import User

load_dotenv()


def create_app():
    app = Flask(__name__)

    app.secret_key = os.environ["SECRET_KEY"]
    db_path = '/app/instance/chores.db'
    app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{db_path}'
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

    db.init_app(app)
    login_manager.init_app(app)
    csrf.init_app(app)
    oauth.init_app(app)

    oauth.register(
        name='google',
        client_id=os.environ["GOOGLE_CLIENT_ID"],
        client_secret=os.environ["GOOGLE_CLIENT_SECRET"],
        server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
        client_kwargs={'scope': 'openid email profile'}
    )

    @login_manager.user_loader
    def load_user(user_id):
        return User.query.get(int(user_id))

    from routes.auth import auth_bp
    from routes.chores import chores_bp
    from routes.ledger import ledger_bp
    from routes.api import api_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(chores_bp)
    app.register_blueprint(ledger_bp)
    app.register_blueprint(api_bp)
    csrf.exempt(api_bp)

    with app.app_context():
        if not os.path.exists('/app/instance'):
            os.makedirs('/app/instance')
        db.create_all()

    return app


if __name__ == '__main__':
    app = create_app()
    app.run(host='0.0.0.0', port=7990)
