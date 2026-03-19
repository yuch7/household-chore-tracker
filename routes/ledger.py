from flask import Blueprint, render_template, request, redirect, url_for
from flask_login import login_required
from sqlalchemy import func
from extensions import db
from models import Transaction

ledger_bp = Blueprint('ledger', __name__)


@ledger_bp.route('/ledger')
@login_required
def ledger():
    usd_txs = Transaction.query.filter_by(currency='USD').order_by(Transaction.timestamp.desc()).all()
    cad_txs = Transaction.query.filter_by(currency='CAD').order_by(Transaction.timestamp.desc()).all()

    usd_total = db.session.query(func.sum(Transaction.amount)).filter_by(currency='USD').scalar() or 0
    cad_total = db.session.query(func.sum(Transaction.amount)).filter_by(currency='CAD').scalar() or 0

    return render_template('ledger.html',
                           usd_txs=usd_txs, usd_total=usd_total,
                           cad_txs=cad_txs, cad_total=cad_total)


@ledger_bp.route('/add_fund/<currency>', methods=['POST'])
@login_required
def add_fund(currency):
    user = request.form.get('user')
    desc = request.form.get('description')
    amount = float(request.form.get('amount'))
    type_ = request.form.get('type')

    final_amount = amount if type_ == 'add' else -amount

    db.session.add(Transaction(
        currency=currency.upper(),
        user=user,
        description=desc,
        amount=final_amount
    ))
    db.session.commit()
    return redirect(url_for('ledger.ledger'))


@ledger_bp.route('/delete_fund/<currency>/<int:id>')
@login_required
def delete_fund(currency, id):
    Transaction.query.filter_by(id=id, currency=currency.upper()).delete()
    db.session.commit()
    return redirect(url_for('ledger.ledger'))
