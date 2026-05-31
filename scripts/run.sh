#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

run_trino_sql() {
    local file=$1
    local description=$2
    echo ""
    echo "=== $description ==="
    echo "    Файл: $file"

    # Читаем файл, разбиваем по ';', выполняем каждый оператор
    local stmt=""
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*--.*$ ]] && { stmt+=$'\n'"$line"; continue; }
        stmt+=$'\n'"$line"
        if [[ "$line" == *";" ]]; then
            local clean
            clean=$(echo "$stmt" | sed '/^[[:space:]]*--/d' | sed '/^[[:space:]]*$/d')
            if [ -n "$clean" ]; then
                local first_word
                first_word=$(echo "$clean" | head -1 | awk '{print toupper($1)}')
                echo "    → $first_word ..."
                echo "$stmt" | docker exec -i trino trino 2>&1 | tail -5
            fi
            stmt=""
        fi
    done < "$file"
    echo "    Готово: $description"
}

echo "============================================="
echo "  Лабораторная работа №4 — ETL через Trino"
echo "============================================="

# 1. Запуск контейнеров
echo ""
echo "=== Запуск Docker-контейнеров ==="
docker-compose up -d

# 2. Ожидание готовности сервисов
echo ""
echo "=== Ожидание готовности сервисов ==="

echo -n "  PostgreSQL: "
until docker exec postgres pg_isready -U postgres > /dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo " готов"

echo -n "  ClickHouse: "
until docker exec clickhouse clickhouse-client --query="SELECT 1" > /dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo " готов"

echo -n "  Trino: "
until docker exec trino trino --execute "SELECT 1" > /dev/null 2>&1; do
    echo -n "."
    sleep 3
done
echo " готов"

# 3. Загрузка данных
bash "$SCRIPT_DIR/01_load_data.sh"

# 4. ETL: исходные данные → модель "снежинка"
run_trino_sql "$SCRIPT_DIR/02_trino_etl.sql" "ETL: Трансформация в модель снежинка"

# 5. Создание отчётов
run_trino_sql "$SCRIPT_DIR/03_trino_reports.sql" "Создание витрин-отчётов"

# 6. Проверка результатов
echo ""
echo "=== Проверка результатов ==="
echo ""
echo "  Таблицы в dwh:"
docker exec clickhouse clickhouse-client --query="SELECT name, total_rows FROM system.tables WHERE database = 'dwh' ORDER BY name"

echo ""
echo "  Размеры таблиц:"
for table in dim_date dim_customer dim_seller dim_product dim_store dim_supplier fact_sales \
    report_sales_by_product report_sales_by_customer report_sales_by_time \
    report_sales_by_store report_sales_by_supplier report_product_quality; do
    count=$(docker exec clickhouse clickhouse-client --query="SELECT count() FROM dwh.$table" 2>/dev/null || echo "0")
    printf "    %-35s %s строк\n" "$table" "$count"
done

echo ""
echo "============================================="
echo "  ETL завершён успешно!"
echo "============================================="
echo ""
echo "  Trino UI:     http://localhost:8080"
echo "  ClickHouse:   http://localhost:8123"
echo "  PostgreSQL:   localhost:5432"
echo ""
