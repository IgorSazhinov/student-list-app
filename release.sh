#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для вывода ошибок
error_exit() {
    echo -e "${RED}❌ Ошибка: $1${NC}" >&2
    exit 1
}

# Функция для проверки статуса команды
check_status() {
    if [ $? -ne 0 ]; then
        error_exit "$1"
    fi
}

# Получаем дату для релиза
RELEASE_DATE=$(date +%Y-%m-%d)
RC_BRANCH="rc/${RELEASE_DATE}"
RELEASE_NOTES="Релиз ${RELEASE_DATE}"
COMMIT_MESSAGE="Тестирование релиза ${RELEASE_DATE} пройдено"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     🚀 Git Flow Release Script v1.0                         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}📅 Дата релиза: ${RELEASE_DATE}${NC}"
echo -e "${YELLOW}🌿 Ветка релиза: ${RC_BRANCH}${NC}"
echo -e "${YELLOW}📝 Комментарий: ${COMMIT_MESSAGE}${NC}"
echo ""

# ============================================
# 1. Проверяем, что мы в чистом состоянии
# ============================================
echo -e "${GREEN}[1/8] Проверка состояния репозитория...${NC}"

# Проверяем, нет ли несохраненных изменений
if ! git diff --quiet || ! git diff --cached --quiet; then
    error_exit "Есть несохраненные изменения. Сначала сделайте commit или stash."
fi

# Проверяем, что мы на dev
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

# Проверяем, существует ли README.md
if [ ! -f "README.md" ]; then
    echo "# Student List App" > README.md
    echo "" >> README.md
    echo "## История релизов" >> README.md
    echo "" >> README.md
    echo "### ${RELEASE_DATE}" >> README.md
    echo "- ${RELEASE_NOTES}" >> README.md
    echo "" >> README.md
    echo "## О проекте" >> README.md
    echo "Приложение для отображения списка студентов с фильтрацией." >> README.md
else
    # Проверяем, есть ли секция "История релизов"
    if ! grep -q "## История релизов" README.md; then
        echo "" >> README.md
        echo "## История релизов" >> README.md
        echo "" >> README.md
    fi
    
    # Добавляем запись о релизе в начало истории
    sed -i.tmp "/## История релизов/a\\
### ${RELEASE_DATE}\\
- ${RELEASE_NOTES}\\
" README.md && rm -f README.md.tmp
fi

# Показываем, что добавили
echo -e "${YELLOW}   Добавлено в README.md:${NC}"
echo -e "${BLUE}   ### ${RELEASE_DATE}${NC}"
echo -e "${BLUE}   - ${RELEASE_NOTES}${NC}"

# ============================================
# 5. Коммитим изменения в rc-ветку
# ============================================
echo -e "${GREEN}[5/8] Коммит изменений в rc-ветку...${NC}"
git add README.md || error_exit "Не удалось добавить README.md"
git commit -m "${COMMIT_MESSAGE}" || error_exit "Не удалось создать коммит"

# Показываем последний коммит
echo -e "${YELLOW}   Создан коммит:${NC}"
git log -1 --oneline

# ============================================
# 6. Пушим rc-ветку на GitHub
# ============================================
echo -e "${GREEN}[6/8] Отправка rc-ветки на GitHub...${NC}"
git push -u origin ${RC_BRANCH} || error_exit "Не удалось отправить ветку ${RC_BRANCH}"

# ============================================
# 7. Инструкция для создания PR на GitHub
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
echo "   - Title: Release ${RELEASE_DATE}"
echo "   - Description: ${RELEASE_NOTES}"
echo ""
read -p "Нажмите Enter, когда Pull Request будет создан и ВЛИТ в main..."

# ============================================
# 8. Вливаем rc-ветку обратно в dev
# ============================================
echo -e "${GREEN}[7/8] Синхронизация dev с rc-веткой...${NC}"

# Обновляем информацию о ветках
git fetch origin || error_exit "Не удалось выполнить fetch"

# Переключаемся на dev
git checkout dev || error_exit "Не удалось переключиться на dev"
git pull origin dev || error_exit "Не удалось обновить dev"

# Вливаем rc-ветку в dev
if git merge-base --is-ancestor origin/${RC_BRANCH} dev; then
    echo -e "${YELLOW}   ⚠️ Ветка ${RC_BRANCH} уже в dev, пропускаем слияние...${NC}"
else
    git merge origin/${RC_BRANCH} --no-ff -m "chore: merge ${RC_BRANCH} into dev after release" || error_exit "Не удалось влить rc в dev"
    git push origin dev || error_exit "Не удалось отправить обновления dev"
    echo -e "${GREEN}   ✅ ${RC_BRANCH} влита в dev${NC}"
fi

# ============================================
# 9. Удаляем rc-ветку (опционально)
# ============================================
echo -e "${GREEN}[8/8] Очистка...${NC}"
read -p "Удалить rc-ветку ${RC_BRANCH}? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git branch -d ${RC_BRANCH} 2>/dev/null || error_exit "Не удалось удалить локальную ветку"
    git push origin --delete ${RC_BRANCH} || error_exit "Не удалось удалить удаленную ветку"
    echo -e "${GREEN}   🗑️ Ветка ${RC_BRANCH} удалена${NC}"
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
echo -e "   ✅ Создана ветка: ${RC_BRANCH}"
echo -e "   ✅ Добавлена запись в README.md: ${RELEASE_NOTES}"
echo -e "   ✅ Коммит: ${COMMIT_MESSAGE}"
echo -e "   ✅ Ветка влита в main (через PR)"
echo -e "   ✅ ${RC_BRANCH} влита обратно в dev"
[[ $REPLY =~ ^[Yy]$ ]] && echo -e "   ✅ Ветка ${RC_BRANCH} удалена"
echo ""
echo -e "${BLUE}🌐 GitHub Pages: https://${REPO_URL}/${NC}"
echo ""