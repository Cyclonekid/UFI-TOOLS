#!/system/bin/sh

read_cpu_stat() {
    while IFS= read -r line; do
        case $line in
            cpu*)
                set -- $line
                cpu=$1
                shift
                total=0
                i=0
                idle=0
                for val in "$@"; do
                    total=$((total + val))
                    if [ "$i" -eq 3 ]; then
                        idle=$val
                    elif [ "$i" -eq 4 ]; then
                        idle=$((idle + val))
                    fi
                    i=$((i + 1))
                done
                echo "$cpu $total $idle"
                ;;
            *)
                break
                ;;
        esac
    done < /proc/stat
}

# 读取两次 CPU 状态，纯变量方式保存
stats1="$(read_cpu_stat)"
sleep 0.1
stats2="$(read_cpu_stat)"

# 处理为 JSON
json="{"
first=1

# 使用“here string”来将变量作为 while 输入
while read -r cpu total1 idle1; do
    # 在 stats2 中查找对应行
    line2=$(echo "$stats2" | grep "^$cpu ")
    total2=$(echo "$line2" | cut -d' ' -f2)
    idle2=$(echo "$line2" | cut -d' ' -f3)

    total_diff=$((total2 - total1))
    idle_diff=$((idle2 - idle1))
    if [ "$total_diff" -eq 0 ]; then
        usage="0.0"
    else
        usage=$(echo "(($total_diff - $idle_diff) * 100.0) / $total_diff" | bc -l | awk '{printf "%.1f", $0}')
    fi

    [ $first -eq 0 ] && json="$json,"
    json="$json\"$cpu\":$usage"
    first=0
done <<EOF
$stats1
EOF

json="$json}"
echo "$json"