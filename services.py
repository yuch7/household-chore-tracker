import calendar
from datetime import timedelta


def get_date_range(interval, target_date):
    """Returns the (start_date, end_date) range for a given interval and target date."""
    if interval == 'daily':
        return target_date, target_date
    elif interval == 'weekly':
        days_since_sunday = (target_date.weekday() + 1) % 7
        start_date = target_date - timedelta(days=days_since_sunday)
        end_date = start_date + timedelta(days=6)
        return start_date, end_date
    elif interval == 'monthly':
        start_date = target_date.replace(day=1)
        _, last_day = calendar.monthrange(target_date.year, target_date.month)
        end_date = target_date.replace(day=last_day)
        return start_date, end_date
    return target_date, target_date
