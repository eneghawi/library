import os
import tarfile
import urllib.request
import pandas as pd
import certifi
import numpy as np
import matplotlib.pyplot at plt
import hashlib
import sklearn

DOWNLOAD_ROOT = "https://raw.githubusercontent.com/ageron/handson-ml/master/"
DATASET_PATH = "datasets/dataset"
DATASET_URL = DOWNLOAD_ROOT + DATASET_PATH + "/dataset.tgz"

print ( DATASET_URL )
def fetch_dataset_data(dataset_url=DATASET_URL, dataset_path= DATASET_PATH):
    """This will create the dataset directory and make sure it is there. After that it will download the datasets and extract it into .CSV

    :dataset_url: TODO
    :dataset_path: TODO
    :returns: TODO

    """
    if not os.path.isdir(dataset_path):
        os.makedirs(dataset_path)
    tgz_path = os.path.join(dataset_path, "houelie.tgz")
    urllib.request.urlretrieve(dataset_url, tgz_path)
    dataset_tgz = tarfile.open(tgz_path)
    dataset_tgz.extractall(path=dataset_path)
    dataset_tgz.close()

def fetch_dataset_data_ssl(dataset_url=DATASET_URL, dataset_path= DATASET_PATH):
    """This will create the dataset directory and make sure it is there. After that it will download the datasets and extract it into .CSV

    :dataset_url: TODO
    :dataset_path: TODO
    :returns: TODO

    """
    if not os.path.isdir(dataset_path):
        os.makedirs(dataset_path)
    tgz_path = os.path.join(dataset_path, "dataset.tgz")
    with urllib.request.urlopen(dataset_url) as d, open(fname,"wb"):
        data = d.read()
        opfile.write(data)
    dataset_tgz = tarfile.open(tgz_path)
    dataset_tgz.extractall(path=dataset_path)
    dataset_tgz.close()

def load_dataset_data(dataset_path=DATASET_PATH):
    """import file from .CSV to a panda panda

    :dataset_path: TODO
    :returns: TODO

    """
    csv_path=os.path.join(dataset_path,"dataset.csv")
    return pd.read_csv(csv_path)

"""
Some Pandas methods: 
    dataset.head() # Method to get the overview of the head of the dataset
    dataset.info() # Method to get the overview of the column and the number of defined variables
    dataset["NameofColumn"] #To display only that column
    dataset["NameofColumn"].value_counts() # Method to display only that column
    dataset["NameofColum"].describe() # To get the average, min, max, percentile, mean, std (Standard Deviation)
"""
def split_train_test(data, test_ratio):
    """Split the dataset randomly based on the test_ratio
    

    :data: TODO
    :test_ratio: TODO
    :returns: TODO
    np.random.seed(42) # put the seed to get the same split everytime on the same Server or PC
    """
    shuffled_indices = np.random.permutation(len(data))
    test_set_size = int(len(data) * test_ratio)
    test_indices = shuffled_indices[:test_set_size]
    train_indices = shuffled_indices[test_set_size]
    return data.iloc[train_indices], data.iloc[test_indices]

"""
train_set, test_set = split_train_test(dataset, 0.2)
print(len(train_set) + "train +", len(test_set) + "test")

%matplotlib inline #only for Jupyter Notebook
dataset.hist(bins=50, figsize=(20,15))
plt.show()
"""

"""
Create a test set
"""


def test_set_check(identifier, test_ratio, hash):
    """return the hash with a value less 256 * test_ratio to split the test data 

    :identifier: TODO
    :test_ratio: TODO
    :: TODO
    :returns: TODO

    """
    return hash(np.int64(identifier)).digest()[-1] < 256 * test_ratio

def split_train_test_by_id(data, test_ratio, id_column, hash = hashlib.md5):
    """TODO: Docstring for split_train_test_by_id.

    :data: TODO
    :test_ratio: TODO
    :id_column: TODO
    :hash: TODO
    :returns: TODO

    """
    ids = data[id_column]
    in_test_set = ids.apply(lambda id_: test_set_check(id_, test_ratio, hash))
    return data.loc[~in_test_set], data.loc[in_test_set]

"""
This will create a index to the data and then it will be used to do the split for test set and training set

dataset = dataset.reset_index()
train_set, test_set = split_train_test_by_id(dataset, 0.2, "index")

This will work if we ensure that the new data will get appended at the end of the file.

A more stable feature is to use the some of the attributes that we know that are unique and they don't change '
dataset_with_id["id"] = data["ColumnThatisstable"] *1000 + data["SecodColumnThatisstable"] 
train_set, test_set = split_train_test_by_id(dataset_with_id, 0.2, "id")
"""

"""
A more usefull solution is to use the Scikit-Learn functions that split the dataset into multiple dataset and one of them is train_test_split. It can also take random_state parameter that allows you to set the random generator seed as explained previously.

train_set, test_set = train_test_split(dataset, test_size = 0.2 , random_state= 42)
"""


