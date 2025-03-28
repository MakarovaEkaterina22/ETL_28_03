#!/bin/bash

# Скрипт для экспорта данных из контейнера Airflow в /home/mgpu/airflow_export

# Параметры
CONTAINER_NAME="business_case_rocket_25-scheduler-1"
AIRFLOW_DATA_DIR="/opt/airflow/data"
HOST_EXPORT_DIR="/home/mgpu/airflow_export"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
EXPORT_PATH="$HOST_EXPORT_DIR/$TIMESTAMP"

# Проверяем существование директории /home/mgpu
if [ ! -d "/home/mgpu" ]; then
    echo "Ошибка: Директория /home/mgpu не существует!"
    exit 1
fi

# Создаем директорию для экспорта
mkdir -p "$EXPORT_PATH/images"

# Устанавливаем правильные права
chown -R mgpu:mgpu "$HOST_EXPORT_DIR"
chmod -R 755 "$HOST_EXPORT_DIR"

# 1. Копируем файл launches.json
echo "Копируем launches.json..."
docker cp "$CONTAINER_NAME:$AIRFLOW_DATA_DIR/launches.json" "$EXPORT_PATH/" && \
    chown mgpu:mgpu "$EXPORT_PATH/launches.json" || \
    echo "Не удалось скопировать launches.json"

# 2. Копируем изображения
echo "Копируем изображения..."
if docker exec "$CONTAINER_NAME" test -d "$AIRFLOW_DATA_DIR/images"; then
    docker cp "$CONTAINER_NAME:$AIRFLOW_DATA_DIR/images/" "$EXPORT_PATH/images/" && \
        chown -R mgpu:mgpu "$EXPORT_PATH/images" || \
        echo "Не удалось скопировать изображения"
else
    echo "Директория с изображениями не найдена в контейнере"
fi

# 3. Создаем файл с информацией
echo "Создаем README..."
echo "Данные экспортированы из контейнера $CONTAINER_NAME" > "$EXPORT_PATH/README.txt"
echo "Дата экспорта: $(date)" >> "$EXPORT_PATH/README.txt"
echo "Количество изображений: $(ls -1 "$EXPORT_PATH/images/" 2>/dev/null | wc -l)" >> "$EXPORT_PATH/README.txt"
chown mgpu:mgpu "$EXPORT_PATH/README.txt"

echo "Данные успешно экспортированы в $EXPORT_PATH"
echo "Владелец файлов: $(stat -c '%U:%G' "$EXPORT_PATH")"