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

check_status() {
    if [ $? -ne 0 ]; then
        error_exit "$1"
    fi
}

# Функция для проверки существования ветки (локально или на удаленном)
branch_exists() {
    local branch_name="$1"
    # Проверяем локальную ветку
    if git show-ref --verify --quiet "refs/heads/${branch_name}"; then
        return 0
    fi
    # Проверяем удаленную ветку
    if git show-ref --verify --quiet "refs/remotes/origin/${branch_name}"; then
        return 0
    fi
    return 1
}

# Функция для генерации уникального имени ветки
generate_rc_branch() {
    local base_date=$(date +%Y-%m-%d)
    local counter=1
    
    # Проверяем базовое имя без счетчика
    if ! branch_exists "rc/${base_date}"; then
        echo "rc/${base_date}"
        return
    fi
    
    # Ищем свободный номер
    while branch_exists "rc/${base_date}-${counter}"; do
        counter=$((counter + 1))
    done
    echo "rc/${base_date}-${counter}"
}

# Функция для подсчета релизов за сегодня в README
get_release_number() {
    local today=$(date +%Y-%m-%d)
    if [ ! -f "README.md" ]; then
        echo "1"
        return
    fi
    
    # Считаем сколько раз встречается дата в истории
    local count=$(grep -c "^### ${today}" README.md 2>/dev/null || echo 0)
    echo $((count + 1))
}

# Получаем уникальные имена
RC_BRANCH=$(generate_rc_branch)
RELEASE_DATE=$(date +%Y-%m-%d)
RELEASE_NUM=$(get_release_number)

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
echo -e "${BLUE}║     🚀 Git Flow Release Script v2.1 (fixed)                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📅 Дата релиза: ${RELEASE_DATE}${NC}"
echo -e "${YELLOW}🌿 Ветка релиза: ${RC_BRANCH}${NC}"
echo -e "${YELLOW}📝 Комментарий: ${COMMIT_MESSAGE}${NC}"
echo ""

# ============================================
# 1. Проверка состояния
# ============================================
echo -e "${GREEN}[1/9] Проверка состояния репозитория...${NC}"

if ! git diff --quiet || ! git diff --cached --quiet; then
    error_exit "Есть несохраненные изменения. Сначала сделайте commit или stash."
fi

CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "dev" ]; then
    echo -e "${YELLOW}   Текущая ветка: ${CURRENT_BRANCH}, переключаемся на dev...${NC}"
    git checkout dev || error_exit "Не удалось переключиться на dev"
fi

# ============================================
# 2. Обновляем dev
# ============================================
echo -e "${GREEN}[2/9] Обновление ветки dev...${NC}"
git pull origin dev || error_exit "Не удалось обновить dev"

# ============================================
# 3. Создаем rc-ветку
# ============================================
echo -e "${GREEN}[3/9] Создание релизной ветки ${RC_BRANCH}...${NC}"
git checkout -b ${RC_BRANCH} || error_exit "Не удалось создать ветку ${RC_BRANCH}"

# ============================================
# 4. Добавляем запись в README.md
# ============================================
echo -e "${GREEN}[4/9] Добавление записи о релизе в README.md...${NC}"

if [ ! -f "README.md" ]; then
    cat > README.md << EOF
# Student List App

## История релизов

### ${RELEASE_DATE}
- ${RELEASE_NOTES}

## О проекте
Приложение для отображения списка студентов с фильтрацией.
EOF
else
    # Проверяем, есть ли секция истории
    if ! grep -q "## История релизов" README.md; then
        echo "" >> README.md
        echo "## История релизов" >> README.md
        echo "" >> README.md
    fi
    
    # Проверяем, есть ли уже запись за сегодня
    if grep -q "^### ${RELEASE_DATE}" README.md; then
        # Временный файл для macOS/Linux совместимости
        TMP_FILE=$(mktemp)
        while IFS= read -r line; do
            echo "$line" >> "$TMP_FILE"
            if [[ "$line" =~ ^###[[:space:]]+${RELEASE_DATE}$ ]]; then
                echo "- ${RELEASE_NOTES}" >> "$TMP_FILE"
            fi
        done < README.md
        mv "$TMP_FILE" README.md
    else
        # Добавляем новую дату после секции истории
        sed -i.bak "/## История релизов/a\\
### ${RELEASE_DATE}\\
- ${RELEASE_NOTES}\\
" README.md && rm -f README.md.bak
    fi
fi

echo -e "${YELLOW}   Добавлено в README.md:${NC}"
echo -e "${BLUE}   - ${RELEASE_NOTES}${NC}"

# ============================================
# 5. Коммитим изменения
# ============================================
echo -e "${GREEN}[5/9] Коммит изменений в rc-ветку...${NC}"
git add README.md || error_exit "Не удалось добавить README.md"
git commit -m "${COMMIT_MESSAGE}" || error_exit "Не удалось создать коммит"

echo -e "${YELLOW}   Создан коммит:${NC}"
git log -1 --oneline

# ============================================
# 6. Пушим rc-ветку
# ============================================
echo -e "${GREEN}[6/9] Отправка rc-ветки на GitHub...${NC}"
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

echo -e "${YELLOW}1. Перейдите по ссылке для создания Pull Request:${NC}"
echo -e "${GREEN}   ${PR_URL}${NC}"
echo ""
echo -e "${YELLOW}2. Настройте Pull Request:${NC}"
echo "   - base: main"
echo "   - compare: ${RC_BRANCH}"
echo "   - Title: ${RELEASE_NOTES}"
echo "   - Description: ${COMMIT_MESSAGE}"
echo ""
read -p "Нажмите Enter, когда Pull Request будет создан и ВЛИТ в main..."

# ============================================
# 8. Вливаем rc в dev
# ============================================
echo -e "${GREEN}[7/9] Синхронизация dev с rc-веткой...${NC}"

# Обновляем информацию о ветках
git fetch origin || error_exit "Не удалось выполнить fetch"

# Переключаемся на dev
git checkout dev || error_exit "Не удалось переключиться на dev"
git pull origin dev || error_exit "Не удалось обновить dev"

# Проверяем, существует ли еще rc-ветка (не удалили ли её при мерже PR)
if ! git fetch origin ${RC_BRANCH} 2>/dev/null; then
    echo -e "${YELLOW}   ⚠️ Ветка ${RC_BRANCH} уже удалена на сервере${NC}"
else
    # Проверяем, влита ли уже rc в dev
    if git merge-base --is-ancestor origin/${RC_BRANCH} dev 2>/dev/null; then
        echo -e "${YELLOW}   ⚠️ Ветка ${RC_BRANCH} уже в dev, пропускаем слияние${NC}"
    else
        git merge origin/${RC_BRANCH} --no-ff -m "chore: merge ${RC_BRANCH} into dev after release" || error_exit "Не удалось влить rc в dev"
        git push origin dev || error_exit "Не удалось отправить обновления dev"
        echo -e "${GREEN}   ✅ ${RC_BRANCH} влита в dev${NC}"
    fi
fi

# ============================================
# 9. Очистка
# ============================================
echo -e "${GREEN}[8/9] Очистка...${NC}"
read -p "Удалить локальную ветку ${RC_BRANCH}? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git branch -d ${RC_BRANCH} 2>/dev/null && echo -e "${GREEN}   🗑️ Локальная ветка удалена${NC}"
fi

# ============================================
# Финальное сообщение
# ============================================
echo -e "${GREEN}[9/9] Завершение...${NC}"
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
[[ $REPLY =~ ^[Yy]$ ]] && echo -e "   ✅ Локальная ветка удалена"
echo ""
echo -e "${BLUE}🌐 GitHub Pages: https://${REPO_URL}/${NC}"
echo ""