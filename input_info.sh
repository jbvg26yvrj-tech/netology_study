#!/bin/bash

# Пути к файлам
INPUT_FILE="/proc/bus/input/devices"
LOG_FILE="input_devices.log"
KNOWN_DEVICES_DB="known_devices.txt"
ROOTUSER_NAME=root
username=$(id -nu)

# Check root user
function checkuser {
    if [ "$username" != "$ROOTUSER_NAME" ]
    then
            echo "Скрипт \"`basename $0`\" может быть запущен только с повышенными привелегиями ."
            exit 1
    fi
}

# Call function 
checkuser

# Проверка на наличие файла
if [ ! -f "$INPUT_FILE" ]; then
    echo "Ошибка: Файл $INPUT_FILE не найден."
    exit 1
fi

# Временный файл для текущего списка имен устройств
CURRENT_DEVICES=$(mktemp)

# 1. Извлекаем только имена устройств и сохраняем во временный файл
grep "^N: Name=" "$INPUT_FILE" | sed 's/N: Name="//;s/"$//' > "$CURRENT_DEVICES"

# 2. Записываем время начала проверки в лог
echo "--- Запуск проверки: $(date '+%Y-%m-%d %H:%M:%S') ---" >> "$LOG_FILE"

NEW_FOUND=false

# 3. Читаем текущие устройства построчно
cat "$CURRENT_DEVICES" | while read -r device; do
    # Проверяем, есть ли это устройство в списке известных
    if ! grep -qFx "$device" "$KNOWN_DEVICES_DB"; then
        # Если устройства нет в базе, это новое устройство
        echo "[NEW] $(date '+%H:%M:%S') - Обнаружено: $device" >> "$LOG_FILE"
        # Добавляем его в базу известных
        echo "$device" >> "$KNOWN_DEVICES_DB"
        NEW_FOUND=true
    fi
done

# Если новых устройств не было, отметим это в логе (опционально)
if [ "$NEW_FOUND" = false ]; then
    echo "Новых устройств не обнаружено." >> "$LOG_FILE"
fi

# Читаем файл построчно
cat "$INPUT_FILE" | while read -r line; do
    # Извлекаем название устройства (строка начинается с N: Name=)
    if [[ $line =~ ^N:\ Name=\"(.*)\" ]]; then
        NAME="${BASH_REMATCH[1]}"
    fi

    # Извлекаем обработчики/события (строка начинается с H: Handlers=)
    if [[ $line =~ ^H:\ Handlers=(.*) ]]; then
        HANDLERS="${BASH_REMATCH[1]}"
        
        # Выводим информацию, когда собрали Name и Handlers
        echo -e "Устройство: \033[1;32m$NAME\033[0m"
        echo -e "Обработчики: $HANDLERS"
        echo "--------------------------------------------------"
    fi
done

echo "--- Проверка завершена ---" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Удаляем временный файл
rm "$CURRENT_DEVICES"
