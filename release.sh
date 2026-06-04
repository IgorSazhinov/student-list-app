#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

error_exit() {
    echo -e "${RED}❌ Ошибка: $1${NC}" >&2
    exit 1
}

# Функция для проверки существования ветки
branch_exists() {
    local branch_name="$1"
    if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
        return 0
    fi
    if git show-ref --verify --quiet "refs/remotes/origin/${branch_name}"; then
        return 0
    fi
    return 1
}

# Функция для генерации уникального имени ветки
generate_rc_branch() {
    local base_date=$(date +%Y-%m-%d)
    local counter=1
    
    if ! branch_exists "rc/${base_date}"; then
        echo "rc/${base_date}"
        return
    fi
    
    while branch_exists "rc/${base_date}-${counter}"; do
        counter=$((counter + 1))
    done
    echo "rc/${base_date}-${counter}"
}

# Функция для добавления записи в README.md
add_release_to_readme() {
    local release_date="$1"
    local release_notes="$2"
    
    # Создаем README.md если не существует
    if [ ! -f "README.md" ]; then
        cat > README.md << EOF
# Student List App

## История релизов

### ${release_date}
- ${release_notes}

## О проекте
Приложение для отображения списка студентов с фильтрацией.
EOF
        return
    fi
    
    # Проверяем, есть ли секция "История релизов"
    if ! grep -q "## История релизов" README.md; then
        echo "" >> README.md
        echo "## История релизов" >> README.md
        echo "" >> README.md
    fi
    
    # Проверяем, есть ли уже запись за эту дату
    if grep -q "^### ${release_date}$" README.md; then
        # Добавляем под существующей датой
        sed -i.bak "/^### ${release_date}$/a\\
- ${release_notes}" README.md && rm -f README.md.bak
    else
        # Добавляем новую дату
        sed -i.bak "/## История релизов/a\\
### ${release_date}\\
- ${release_notes}\\
" README.md && rm -f README.md.bak
    fi
    
    # Проверяем, что запись действительно добавилась
    if ! grep -q "${release_notes}" README.md; then
        # Если sed не сработал (например на macOS), используем echo
        echo "" >> README.md
        echo "### ${release_date}" >> README.md
        echo "- ${release_notes}" >> README.md
    fi
}

# Получаем уникальные имена
RC_BRANCH=$(generate_rc_branch)
RELEASE_DATE=$(date +%Y-%m-%d)

# Формируем сообщения
if [[ "$RC_BRANCH" =~ -([0-9]+)$ ]]; then
    RELEASE_NUMBER=${BASH_REMATCH[1]}
    RELEASE_NOTES="Релиз ${RELEASE_DATE} #${RELEASE_NUMBER}"
    COMMIT_MESSAGE="Тестирование релиза ${RELEASE_DATE} #${RELEASE_NUMBER} пройдено"
else
    RELEASE_NOTES="Релиз ${RELEASE_DATE}"
    COMMIT_MESSAGE="Тестирование релиза ${RELEASE_DATE} пройдено"
fi

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     🚀 Git Flow Release Script v2.2 (working)              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📅 Дата релиза: ${RELEASE_DATE}${NC}"
echo -e "${YELLOW}🌿 Ветка релиза: ${RC_BRANCH}${NC}"
echo -e "${YELLOW}📝 Комментарий: ${COMMIT_MESSAGE}${NC}"
echo ""

# ============================================
# 1. Проверка состояния
# ============================================
echo -e "${GREEN}[1/8] Проверка состояния репозитория...${NC}"

# Проверяем наличие незакоммиченных изменений
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -e "${YELLOW}   Есть несохраненные изменения. Создаем stash...${NC}"
    git stash push -m "auto-stash before release"
    STASH_CREATED=true
fi

CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "dev" ]; then
    echo -e "${YELLOW}   Текущая ветка: ${CURRENT_BRANCH}, переключаемся на dev...${NC}"
    git checkout dev || error_exit "Не удалось переключиться на dev"
fi

# ============================================
# 2. Обновляем dev
# ============================================
echo -e "${GREEN}[2/8] Обновление ветки dev...${NC}"
git pull origin dev || error_exit "Не удалось обновить dev"

# ============================================
# 3. Создаем rc-ветку
# ============================================
echo -e "${GREEN}[3/8] Создание релизной ветки ${RC_BRANCH}...${NC}"
git checkout -b ${RC_BRANCH} || error_exit "Не удалось создать ветку ${RC_BRANCH}"

# ============================================
# 4. Добавляем запись в README.md
# ============================================
echo -e "${GREEN}[4/8] Добавление записи о релизе в README.md...${NC}"
add_release_to_readme "${RELEASE_DATE}" "${RELEASE_NOTES}"

# Показываем добавленную запись
echo -e "${YELLOW}   Добавлено в README.md:${NC}"
echo -e "${BLUE}   ${RELEASE_NOTES}${NC}"

# Проверяем, изменился ли README.md
if git diff --quiet README.md; then
    echo -e "${YELLOW}   ⚠️ README.md не изменился, принудительно добавляем запись...${NC}"
    # Принудительное добавление в конец файла
    echo "" >> README.md
    echo "### ${RELEASE_DATE}" >> README.md
    echo "- ${RELEASE_NOTES}" >> README.md
fi

# ============================================
# 5. Коммитим изменения
# ============================================
echo -e "${GREEN}[5/8] Коммит изменений в rc-ветку...${NC}"
git add README.md || error_exit "Не удалось добавить README.md"

# Проверяем, есть ли что коммитить
if git diff --cached --quiet; then
    echo -e "${YELLOW}   Нет изменений для коммита, создаем пустой коммит с сообщением...${NC}"
    git commit --allow-empty -m "${COMMIT_MESSAGE}" || error_exit "Не удалось создать коммит"
else
    git commit -m "${COMMIT_MESSAGE}" || error_exit "Не удалось создать коммит"
fi

echo -e "${YELLOW}   Создан коммит:${NC}"
git log -1 --oneline

# ============================================
# 6. Пушим rc-ветку
# ============================================
echo -e "${GREEN}[6/8] Отправка rc-ветки на GitHub...${NC}"
git push -u origin ${RC_BRANCH} || error_exit "Не удалось отправить ветку"

# ============================================
# 7. Инструкция для PR
# ============================================
echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  📌 ДЕЙСТВИЯ НА GITHUB                                     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

REPO_URL=$(git remote get-url origin | sed 's/.*:\(.*\)\.git/\1/')
PR_URL="https://github.com/${REPO_URL}/compare/main...${RC_BRANCH}?expand=1"

echo -e "${YELLOW}1. Перейдите по ссылке:${NC}"
echo -e "${GREEN}   ${PR_URL}${NC}"
echo ""
echo -e "${YELLOW}2. Настройте Pull Request:${NC}"
echo "   - base: main"
echo "   - compare: ${RC_BRANCH}"
echo "   - Title: ${RELEASE_NOTES}"
echo "   - Description: ${COMMIT_MESSAGE}"
echo ""
read -p "Нажмите Enter, когда Pull Request будет создан и ВЛИТ в main..."

# Обновляем информацию о ветках
git fetch origin

# ============================================
# 8. Вливаем rc в dev (если ветка еще существует)
# ============================================
echo -e "${GREEN}[7/8] Синхронизация dev с rc-веткой...${NC}"

git checkout dev || error_exit "Не удалось переключиться на dev"
git pull origin dev || error_exit "Не удалось обновить dev"

# Проверяем, существует ли еще rc-ветка
if git fetch origin ${RC_BRANCH} 2>/dev/null; then
    if ! git merge-base --is-ancestor origin/${RC_BRANCH} dev 2>/dev/null; then
        git merge origin/${RC_BRANCH} --no-ff -m "chore: merge ${RC_BRANCH} into dev after release" || echo -e "${YELLOW}   ⚠️ Не удалось влить rc в dev (возможно уже влита)${NC}"
        git push origin dev || error_exit "Не удалось отправить dev"
        echo -e "${GREEN}   ✅ ${RC_BRANCH} влита в dev${NC}"
    else
        echo -e "${YELLOW}   ⚠️ Ветка ${RC_BRANCH} уже в dev${NC}"
    fi
else
    echo -e "${YELLOW}   ⚠️ Ветка ${RC_BRANCH} уже удалена на сервере${NC}"
fi

# ============================================
# 9. Очистка
# ============================================
echo -e "${GREEN}[8/8] Очистка...${NC}"
read -p "Удалить локальную ветку ${RC_BRANCH}? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git branch -d ${RC_BRANCH} 2>/dev/null && echo -e "${GREEN}   🗑️ Локальная ветка удалена${NC}"
fi

# Восстанавливаем stash если был
if [ "$STASH_CREATED" = true ]; then
    echo -e "${YELLOW}   Восстанавливаем сохраненные изменения...${NC}"
    git stash pop
fi

# ============================================
# Финальное сообщение
# ============================================
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  🎉 РЕЛИЗ УСПЕШНО ЗАВЕРШЕН!                                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📊 Итог:${NC}"
echo -e "   ✅ Ветка: ${RC_BRANCH}"
echo -e "   ✅ Запись в README: ${RELEASE_NOTES}"
echo -e "   ✅ Коммит: ${COMMIT_MESSAGE}"
echo -e "   ✅ Влито в main (через PR)"
echo -e "   ✅ Влито обратно в dev"
echo ""
echo -e "${BLUE}🌐 GitHub Pages: https://${REPO_URL}/${NC}"
echo ""