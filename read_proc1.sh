#!/bin/bash

# 1. Сначала выбираем параметры ОДИН РАЗ
selected_params=""
count=0
count_dir=0
new_dir=0
ROOTUSER_NAME=root
username=$(id -nu)
#file logs
output_file="list_proc.txt"
log="log-file.txt"
dir="/proc"
start_time=$(date "+%Y-%m-%d %H:%M:%SZ")
temp_old_pids=$(mktemp /tmp/pid.XXX) 

function create_table {
   fmt="%-25.25s | %-30.45s"
   headers=("PID" "PATH")

   for p in $selected_params; do
      fmt+="|  %-30.45s"
      headers+=("${p^^}")
   done
   fmt+="\n"

  printf "$fmt" "${headers[@]}"
}

echo "--- Скрипт запущен: $start_time ---" >> "$log"
# Если файл лога уже существует, извлекаем из него только PID
if [[ -f "$output_file" ]]; then
   awk '{print $1}' "$output_file" | grep -E '^[0-9]+$' > "$temp_old_pids"
fi

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


# Start select , for choose different  argument
echo "Выберите не менее 4 параметров (введите 'quit' для завершения выбора):"
options=(cmdline environ limits status cwd root mounts fd fdinfo quit)

select opt in "${options[@]}"; do
    case $opt in
        quit)
            if [ "$count" -lt 1 ]; then
                echo "Ошибка: выберите минимум 4 параметра (сейчас $count)"
            else
                break # Выходим из выбора и идем к процессам
            fi
            ;;
        "") echo "Неверный выбор" ;;
        *)
            selected_params+="$opt "
            ((count++))
            echo "Добавлено: $opt (Всего: $count)"
            ;;
    esac
done

# start main script

echo "Запись пошла..." >> "$log"

#call function for create table to output user 
create_table

# start 
if [ -d "$dir" ]; then
   for i in "$dir"/[0-9]*/; do
       ((count_dir++))
       if [[ -e  "$i" ]]; then
          pid=$(basename "$i")
          echo "$pid" >> "$output_file" 
          exe_path=$( readlink -f "$i/exe"  2> /dev/null )
        if [[ -z "$exe_path" || "$exe_path" == *"/proc/"*  ]]; then
            exe_path=$( cat  "$i/comm"  2> /dev/null )
        fi
        [[ -z "$exe_path" ]] && exe_path="Kernel process"
        if ! grep -qxw "$pid" "$temp_old_pids"; then
           echo  "$pid" >> "$output_file"
           ((new_dir++))
        fi
    fi

    row=("$pid" "$exe_path")
    for param in $selected_params; do
        case $param in
            cmdline)
                val=$(tr '\0' ' ' < "/proc/$pid/cmdline" | cut -c 1-20)
                row+=( ${val:-N/A} ) ;;
            status)
                val=$(grep "Name:" "/proc/$pid/status" | awk '{print $2}')
                row+=("$val") ;;
            environ)
                val=$(tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | wc -l)
                row+=("$val vars");;
            limits)
                val=$(grep "Max open files" "/proc/$pid/limits" | awk '{print $4}')
                row+=("$val");;
            cwd)
                val=$(readlink "/proc/$pid/cwd")
                row+=("$val");;
            root)
                val=$(readlink "/proc/$pid/root")
                row+=("$val");;
            mounts)
                # Считаем количество смонтированных систем для процесса
                val=$(wc -l < "/proc/$pid/mounts" 2>/dev/null)
                row+=("$val items") ;;
            fd)
                # Считаем количество открытых дескрипторов (файлов)
                val=$(ls "/proc/$pid/fd" 2>/dev/null | wc -l)
                row+=("$val") ;;
            fdinfo)
                # Читаем позицию в первом найденном файле (например, дескриптор 0)
                first_fd=$(ls "/proc/$pid/fdinfo" 2>/dev/null | head -n 1)
                if [[ -n "$first_fd" ]]; then
                    val=$(grep "pos:" "/proc/$pid/fdinfo/$first_fd" 2>/dev/null | awk '{print $2}')
                    row+=("$val")
                else
                    row+=("N/A")
                fi;;
        esac
    done
    # printf "%s\n" "--------------------------------------------------------------------------"
    printf "$fmt" ${row[@]}
   done
fi
end_time=$(date "+%Y-%m-%d %H:%M:%S")
echo "--- Скрипт завершен: $end_time --- всего значений: $count_dir , новых $new_dir" | tee -a "$log"
rm "$temp_old_pids" 2> /dev/null
echo "Готово! Новые процессы занесены в $output_file всего значений: $count_dir , новых $new_dir "