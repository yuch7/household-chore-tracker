"""
One-time migration script to:
1. Merge usd_transaction and cad_transaction tables into a unified transaction table
2. Add indexes to chore_log table
3. Preserve all existing data

Run this ONCE before deploying the new code:
    python migrate_db.py /path/to/chores.db
"""
import sqlite3
import sys


def migrate(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Check which tables exist
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = {row[0] for row in cursor.fetchall()}

    # --- Merge USD/CAD transactions into unified transaction table ---
    if 'transaction' not in tables:
        print("Creating unified 'transaction' table...")
        cursor.execute('''
            CREATE TABLE "transaction" (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                currency VARCHAR(3) NOT NULL,
                "user" VARCHAR(50),
                description VARCHAR(100),
                amount FLOAT,
                timestamp DATETIME DEFAULT (datetime('now'))
            )
        ''')

        if 'usd_transaction' in tables:
            print("Copying USD transactions...")
            cursor.execute('''
                INSERT INTO "transaction" (currency, "user", description, amount, timestamp)
                SELECT 'USD', "user", description, amount, timestamp
                FROM usd_transaction
            ''')
            count = cursor.rowcount
            print(f"  Copied {count} USD transactions.")

        if 'cad_transaction' in tables:
            print("Copying CAD transactions...")
            cursor.execute('''
                INSERT INTO "transaction" (currency, "user", description, amount, timestamp)
                SELECT 'CAD', "user", description, amount, timestamp
                FROM cad_transaction
            ''')
            count = cursor.rowcount
            print(f"  Copied {count} CAD transactions.")

        # Create index on currency
        cursor.execute('CREATE INDEX IF NOT EXISTS ix_transaction_currency ON "transaction" (currency)')

        # Drop old tables
        if 'usd_transaction' in tables:
            cursor.execute('DROP TABLE usd_transaction')
            print("Dropped old usd_transaction table.")
        if 'cad_transaction' in tables:
            cursor.execute('DROP TABLE cad_transaction')
            print("Dropped old cad_transaction table.")
    else:
        print("'transaction' table already exists, skipping merge.")

    # --- Add indexes to chore_log ---
    print("Adding indexes to chore_log...")
    cursor.execute('CREATE INDEX IF NOT EXISTS ix_chore_log_user_name ON chore_log (user_name)')
    cursor.execute('CREATE INDEX IF NOT EXISTS ix_chore_log_task_name ON chore_log (task_name)')
    cursor.execute('CREATE INDEX IF NOT EXISTS ix_chore_log_date_completed ON chore_log (date_completed)')

    conn.commit()
    conn.close()
    print("Migration complete!")


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python migrate_db.py /path/to/chores.db")
        sys.exit(1)
    migrate(sys.argv[1])
