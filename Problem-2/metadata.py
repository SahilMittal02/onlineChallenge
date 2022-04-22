import json
import requests

base_url = "https://169.254.169.254"

api_version = "2021-02-01"
final_endpoint = base_url + "/metadata/instance?api-version=" + api_version
proxies = {
    "http": None
    "https": None
}
def querydata(key):
    endpoint = base_url + "/metadata/instance/${key}?api-version=" + api_version
    raw_val = requests.get(final_endpoint, headers=headers, proxies=proxies)
    json_val = raw_val.json()
    
def main():
    headers = {'Metadata':'True'}
    raw_val = requests.get(final_endpoint, headers=headers, proxies=proxies)
    json_val = raw_val.json()

if __name__== "__main__":
    main()
    filter1=input("Enter Key/value that you want to check/filter")
    querydata(filter1) 