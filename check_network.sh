#!/bin/bash
ROOTUSER_NAME=root
username=$(id -nu)
PREFIX="${1:-NOT_SET}"
INTERFACE="${2:-NOT_SET}"
USER_SUBNET="$3"
USER_HOST="$4"
SUBNET_RANGE="${USER_SUBNET:-"{1..255}"}"
HOST_RANGE="${USER_HOST:-"{1..255}"}"
PREFIX_REGEX="^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?\.)(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
SUBHOST_REGEX="^([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"

function checkuser {
    if [ "$username" != "$ROOTUSER_NAME" ]
    then
	    echo "Скрипт \"`basename $0`\" может быть запущен только с повышенными привелегиями ."
	    exit 1
    fi
}

function validate_input {
    value="$1"
    name="$2"
    regex="$3"

    # Если значение пустое — пропускаем (используем дефолт позже)
    if [[ -z "$value" || "$value" == "NOT_SET" ]]; then
        if [[ "$name" == "PREFIX" || "$name" == "INTERFACE" ]]; then
            echo "КРИТИЧЕСКАЯ ОШИБКА: Параметр $name обязателен для работы!"
            echo "Использование: \"`basename $0`\" <prefix> <interface> [subnet] [host]"
            exit 1
        else
            # Для SUBNET и HOST просто выводим инфо, что будет цикл
            echo "$name не задан, будет просканирован весь диапазон {1..255}."
            return 0
        fi

    # 2. Если значение установлено, но не проходит регулярку
    elif [ -n "$value" ] && [[ "$name" != "INTERFACE" ]] && [[ ! "$value" =~ $regex ]]; then
        if [[ "$name" == "PREFIX" ]]; then
            echo "ОШИБКА ВАЛИДАЦИИ: Параметр $name должен иметь формат X.X"
            exit 1
        else
            # Для SUBNET и HOST просто выводим инфо, что будет цикл
            echo "ОШИБКА ВАЛИДАЦИИ: Параметр $name должен иметь число от 0 до 255"
            exit 1
        fi
    fi
}

checkuser
validate_input "$PREFIX" "PREFIX" "$PREFIX_REGEX"
validate_input "$INTERFACE" "INTERFACE"
validate_input "$USER_SUBNET" "USER_SUBNET" "$SUBHOST_REGEX"
validate_input "$USER_HOST" "USER_HOST" "$SUBHOST_REGEX"

trap 'echo "Ping exit (Ctrl-C)"; exit' SIGINT

for SUBNET in $(eval echo "$SUBNET_RANGE")
do
	for HOST in $(eval echo "$HOST_RANGE");
	do
	    echo "[*] IP : ${PREFIX}.${SUBNET}.${HOST}"
            arping -c 3 -w 1 -i "$INTERFACE" "${PREFIX}.${SUBNET}.${HOST}" 2> /dev/null
	done
done
