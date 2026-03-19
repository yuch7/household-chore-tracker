let moveMode = false;
let taskToMove = null;
let bsCollapse;

const csrfToken = document.querySelector('meta[name="csrf-token"]').getAttribute('content');

document.addEventListener('DOMContentLoaded', function() {
    const collapseEl = document.getElementById('dailyCollapse');
    bsCollapse = new bootstrap.Collapse(collapseEl, { toggle: false });

    var calendarEl = document.getElementById('calendar');
    var calendar = new FullCalendar.Calendar(calendarEl, {
        initialView: 'dayGridMonth',
        height: 'auto',
        headerToolbar: { left: 'prev,next today', center: 'title', right: 'dayGridMonth,dayGridWeek' },
        editable: true,
        droppable: true,
        eventLongPressDelay: 300,
        events: '/api/events',
        displayEventTime: true,

        eventDrop: function(info) {
            var props = info.event.extendedProps;
            if (props.type === 'event') {
                info.revert();
                return;
            }
            executeMove(info.event.id, info.event.startStr.split('T')[0], () => {
                info.revert();
            });
        },

        dateClick: function(info) {
            if (moveMode && taskToMove) {
                executeMove(taskToMove, info.dateStr, cancelMove);
            } else {
                updateCollapsibleList(info.dateStr, calendar);
            }
        }
    });
    calendar.render();
});

function updateCollapsibleList(dateStr, calendar) {
    const listContent = document.getElementById('collapse-list-content');
    const label = document.getElementById('selected-date-label');
    const events = calendar.getEvents().filter(e => e.startStr.split('T')[0] === dateStr);

    label.innerHTML = `📅 Tasks for <strong>${dateStr}</strong>`;
    listContent.innerHTML = "";

    if (events.length === 0) {
        listContent.innerHTML = `<div class="py-3 text-center text-muted">No chores logged for this day.</div>`;
    } else {
        events.forEach(event => {
            const props = event.extendedProps;
            const isChore = props.type === 'chore';
            const item = document.createElement('div');
            item.className = "list-group-item d-flex justify-content-between align-items-center bg-transparent px-0";

            let timeStr = '';
            if (!isChore && event.start && !event.allDay) {
                timeStr = event.start.toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'}) + ' ';
            }

            let actions = '';
            if (isChore) {
                actions = `
                    <button class="btn btn-sm btn-outline-primary me-2" onclick="startMove('${event.id}', '${event.title.split('(')[0]}')">Move</button>
                    <button class="btn btn-sm btn-link text-danger p-0 text-decoration-none" onclick="deleteChore(${props.dbId})">Delete</button>
                `;
            } else {
                actions = `
                    <button class="btn btn-sm btn-outline-secondary me-2" onclick="openEditEvent(${props.dbId})">Edit</button>
                    <button class="btn btn-sm btn-link text-danger p-0 text-decoration-none" onclick="deleteCalendarEvent(${props.dbId})">Delete</button>
                `;
            }

            item.innerHTML = `
                <span>
                    <span class="badge me-2" style="background-color: ${event.backgroundColor}; width: 10px; height: 10px; display: inline-block; padding: 0;"> </span>
                    ${timeStr}${event.title}
                </span>
                <div>${actions}</div>
            `;
            listContent.appendChild(item);
        });
    }
    bsCollapse.show();
    document.getElementById('dailyCollapse').scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

function executeMove(id, newDate, errorCallback) {
    fetch('/api/move_chore', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'X-CSRFToken': csrfToken
        },
        body: JSON.stringify({ id: id, start: newDate })
    }).then(response => {
        if (response.ok) {
            location.reload();
        } else {
            alert("Move failed: Weekly limit reached for this task!");
            if (errorCallback) errorCallback();
        }
    });
}

function startMove(id, title) {
    moveMode = true;
    taskToMove = id;
    document.getElementById('move-task-name').innerText = title;
    document.getElementById('move-banner').classList.remove('d-none');
    bsCollapse.hide();
    document.getElementById('calendar').classList.add('moving-active');
}

function cancelMove() {
    moveMode = false;
    taskToMove = null;
    document.getElementById('move-banner').classList.add('d-none');
    document.getElementById('calendar').classList.remove('moving-active');
}

function deleteChore(dbId) {
    if (confirm("Delete this chore entry?")) {
        fetch(`/api/delete_log/${dbId}`, {
            method: 'DELETE',
            headers: { 'X-CSRFToken': csrfToken }
        }).then(() => location.reload());
    }
}

function deleteCalendarEvent(dbId) {
    if (confirm("Delete this event?")) {
        fetch(`/api/delete_event/${dbId}`, {
            method: 'DELETE',
            headers: { 'X-CSRFToken': csrfToken }
        }).then(() => location.reload());
    }
}

function openEditEvent(dbId) {
    fetch(`/api/event/${dbId}`).then(r => r.json()).then(data => {
        document.getElementById('edit-event-id').value = data.id;
        document.getElementById('edit-event-title').value = data.title;
        document.getElementById('edit-event-date').value = data.event_date;
        document.getElementById('edit-event-time').value = data.start_time;
        document.getElementById('edit-event-duration').value = data.duration_minutes;

        const colorRadio = document.querySelector(`input[name="edit_event_color"][value="${data.color}"]`);
        if (colorRadio) colorRadio.checked = true;

        new bootstrap.Modal(document.getElementById('editEventModal')).show();
    });
}

function saveEditEvent() {
    const id = document.getElementById('edit-event-id').value;
    const color = document.querySelector('input[name="edit_event_color"]:checked');
    const payload = {
        title: document.getElementById('edit-event-title').value,
        event_date: document.getElementById('edit-event-date').value,
        start_time: document.getElementById('edit-event-time').value || null,
        duration_minutes: document.getElementById('edit-event-duration').value,
        color: color ? color.value : '#28a745'
    };

    fetch(`/api/event/${id}`, {
        method: 'PUT',
        headers: {
            'Content-Type': 'application/json',
            'X-CSRFToken': csrfToken
        },
        body: JSON.stringify(payload)
    }).then(response => {
        if (response.ok) {
            location.reload();
        } else {
            alert('Failed to update event.');
        }
    });
}

function closeCollapse() { bsCollapse.hide(); }
