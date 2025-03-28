import json
import pathlib

import airflow.utils.dates
import requests
import requests.exceptions as requests_exceptions
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator

dag = DAG(
    dag_id="download_past_rocket_local",
    description="Download rocket pictures of past launched rockets.",
    start_date=airflow.utils.dates.days_ago(14),
    schedule_interval="@daily",
    catchup=False, # Добавляем чтобы не запускать старые пропущенные задачи
)

# Изменение пути для скачивания JSON-файла в папку data с прошлыми запусками
download_past_launches = BashOperator(
    task_id="download_past_launches",
    bash_command="curl -o /opt/airflow/data/past_launches.json -L 'https://ll.thespacedevs.com/2.0.0/launch/previous'",  # noqa: E501
    dag=dag,
)

def _get_past_pictures():
    # Обеспечиваем существование директории для изображений в папке data
    images_dir = "/opt/airflow/data/past_images"
    pathlib.Path(images_dir).mkdir(parents=True, exist_ok=True)

    # Загружаем все картинки из past_launches.json
    with open("/opt/airflow/data/past_launches.json") as f:
        launches = json.load(f)
        image_urls = [launch["image"] for launch in launches["results"]]
        for image_url in image_urls:
            try:
                response = requests.get(image_url)
                image_filename = image_url.split("/")[-1]
                target_file = f"{images_dir}/{image_filename}"
                with open(target_file, "wb") as f:
                    f.write(response.content)
                print(f"Downloaded {image_url} to {target_file}")
            except requests_exceptions.MissingSchema:
                print(f"{image_url} appears to be an invalid URL.")
            except requests_exceptions.ConnectionError:
                print(f"Could not connect to {image_url}.")

get_past_pictures = PythonOperator(
    task_id="get_past_pictures", python_callable=_get_past_pictures, dag=dag
)

# Обновляем команду уведомления, чтобы она считала количество изображений в папке data/past_images
notify_past = BashOperator(
    task_id="notify_past",
    bash_command='echo "There are now $(ls /opt/airflow/data/past_images/ | wc -l) past images."',
    dag=dag,
)

download_past_launches >> get_past_pictures >> notify_past
