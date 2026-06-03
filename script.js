let students = [];

async function loadStudents() {
    try {
        const response = await fetch('students.json');
        students = await response.json();
        updateStats();
        renderList();
    } catch (error) {
        console.error('Ошибка загрузки списка студентов:', error);
        document.getElementById('studentList').innerHTML = 
            '<li class="student-item" style="color: red;">Ошибка загрузки данных</li>';
    }
}

function renderList(filterText = '') {
    const listElement = document.getElementById('studentList');
    const filteredStudents = filterText 
        ? students.filter(s => s.family.toLowerCase().includes(filterText.toLowerCase()))
        : students;
    
    if (filteredStudents.length === 0) {
        listElement.innerHTML = '<li class="student-item">Студенты не найдены</li>';
        return;
    }
    
    listElement.innerHTML = filteredStudents
        .map(student => `
            <li class="student-item">
                <div class="student-name">${escapeHtml(student.family)} ${student.name || ''}</div>
            </li>
        `)
        .join('');
}

function updateStats() {
    document.getElementById('totalCount').textContent = students.length;
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Фильтрация в реальном времени
const searchInput = document.getElementById('searchInput');
searchInput.addEventListener('input', (e) => {
    renderList(e.target.value);
});

document.getElementById('resetFilter').addEventListener('click', () => {
    searchInput.value = '';
    renderList('');
});

// Загрузка данных
loadStudents();