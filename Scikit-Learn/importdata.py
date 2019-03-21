import os
import tarfile
import urllib.request
import panda as pd
DOWNLOAD_ROOT = "https://raw.githubusercontent.com/ageron/handson-ml/master/"
HOUSING_PATH = "datasets/housing"
HOUSING_URL = DOWNLOAD_ROOT + HOUSING_PATH + "/housing.tgz"

def fetch_housing_data(housing_url=HOUSING_URL, housing_path= HOUSING_PATH):
    """This will create the dataset directory and make sure it is there. After that it will download the datasets and extract it into .CSV

    :housing_url: TODO
    :housing_path: TODO
    :returns: TODO

    """
    if not os.path.isdir(housing_path):
        os.makedirs(housing_path)
    tgz_path = os.path.join(housing_path, "housing.tgz")
    urllib.request.urlretrieve(housing_url, tgz_path)
    housing_tgz = tarfile.open(tgz_path)
    housing_tgz.extractall(path=housing_path)
    housing_tgz.close()

def load_housing_data(housing_path=HOUSING_PATH)
    csv_path = os.path.join(housing_path,"housing.csv")
    return pd.read_csv(csv_path)

