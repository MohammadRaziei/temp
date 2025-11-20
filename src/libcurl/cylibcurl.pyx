# distutils: language = c++
# cython: language_level=3

"""
Cython bindings for libcurl.
"""

from libc.stdlib cimport malloc, free
from libc.string cimport strcpy, strlen
from libcpp.string cimport string
from libcpp cimport bool

# Import curl headers
cdef extern from "curl/curl.h":
    ctypedef void CURL
    ctypedef struct curl_slist:
        char* data
        curl_slist* next
    
    ctypedef enum CURLcode:
        CURLE_OK = 0
    
    ctypedef enum CURLoption:
        CURLOPT_URL = 10002
        CURLOPT_WRITEDATA = 10001
        CURLOPT_WRITEFUNCTION = 20011
        CURLOPT_HTTPHEADER = 10023
        CURLOPT_POST = 10015
        CURLOPT_POSTFIELDS = 10060
        CURLOPT_FOLLOWLOCATION = 52
    
    ctypedef enum CURLINFO:
        CURLINFO_RESPONSE_CODE = 2097154
    
    ctypedef size_t (*curl_write_callback)(char* ptr, size_t size, size_t nmemb, void* userdata)
    
    CURL* curl_easy_init()
    void curl_easy_cleanup(CURL* curl)
    CURLcode curl_easy_setopt(CURL* curl, CURLoption option, ...)
    CURLcode curl_easy_perform(CURL* curl)
    const char* curl_easy_strerror(CURLcode code)
    CURLcode curl_easy_getinfo(CURL* curl, CURLINFO info, ...)
    curl_slist* curl_slist_append(curl_slist* list, const char* string)
    void curl_slist_free_all(curl_slist* list)


cdef class CurlResponse:
    """Response object for curl requests."""
    
    cdef public int status_code
    cdef public bytes data
    cdef public dict headers
    
    def __init__(self, status_code=0, data=b"", headers=None):
        self.status_code = status_code
        self.data = data
        self.headers = headers or {}
    
    @property
    def text(self):
        """Return response data as text."""
        return self.data.decode('utf-8', errors='ignore')
    
    def json(self):
        """Parse response data as JSON."""
        import json
        return json.loads(self.text)


cdef size_t write_callback(char* ptr, size_t size, size_t nmemb, void* userdata) noexcept:
    """Callback function to handle response data."""
    cdef size_t total_size = size * nmemb
    cdef list response_data = <list>userdata
    response_data.append(ptr[:total_size])
    return total_size


cdef class Curl:
    """Cython wrapper for libcurl."""
    
    cdef CURL* curl_ptr
    cdef list response_data
    cdef dict response_headers
    cdef int status_code
    
    def __cinit__(self):
        self.curl_ptr = curl_easy_init()
        self.response_data = []
        self.response_headers = {}
        self.status_code = 0
    
    def __dealloc__(self):
        if self.curl_ptr:
            curl_easy_cleanup(self.curl_ptr)
    
    def get(self, url: str, headers: dict = None) -> CurlResponse:
        """Perform a GET request."""
        return self._request("GET", url, headers=headers)
    
    def post(self, url: str, data: dict = None, headers: dict = None) -> CurlResponse:
        """Perform a POST request."""
        return self._request("POST", url, data=data, headers=headers)
    
    def _request(self, method: str, url: str, data: dict = None, headers: dict = None) -> CurlResponse:
        """Perform an HTTP request."""
        cdef CURLcode res
        cdef curl_slist* header_list = NULL
        
        # Reset response data
        self.response_data = []
        self.response_headers = {}
        
        # Set URL
        res = curl_easy_setopt(self.curl_ptr, CURLOPT_URL, url.encode('utf-8'))
        if res != CURLE_OK:
            raise RuntimeError(f"Failed to set URL: {curl_easy_strerror(res).decode('utf-8')}")

        # Set write callback
        res = curl_easy_setopt(self.curl_ptr, CURLOPT_WRITEFUNCTION, <curl_write_callback>write_callback)
        if res != CURLE_OK:
            raise RuntimeError(f"Failed to set write callback: {curl_easy_strerror(res).decode('utf-8')}")

        # Set write data
        res = curl_easy_setopt(self.curl_ptr, CURLOPT_WRITEDATA, <void*>self.response_data)
        if res != CURLE_OK:
            raise RuntimeError(f"Failed to set write data: {curl_easy_strerror(res).decode('utf-8')}")

        # Set headers
        if headers:
            for key, value in headers.items():
                header_string = f"{key}: {value}".encode('utf-8')
                header_list = curl_slist_append(header_list, <char*>header_string)

            if header_list:
                res = curl_easy_setopt(self.curl_ptr, CURLOPT_HTTPHEADER, header_list)
                if res != CURLE_OK:
                    curl_slist_free_all(header_list)
                    raise RuntimeError(f"Failed to set headers: {curl_easy_strerror(res).decode('utf-8')}")

        # Set method-specific options
        if method == "POST":
            res = curl_easy_setopt(self.curl_ptr, CURLOPT_POST, 1)
            if res != CURLE_OK:
                if header_list:
                    curl_slist_free_all(header_list)
                raise RuntimeError(f"Failed to set POST method: {curl_easy_strerror(res).decode('utf-8')}")

            if data:
                # Convert data to form-encoded string
                import urllib.parse
                post_data = urllib.parse.urlencode(data).encode('utf-8')
                res = curl_easy_setopt(self.curl_ptr, CURLOPT_POST, 1)
                res = curl_easy_setopt(self.curl_ptr, CURLOPT_POSTFIELDS, <char*>post_data)
                if res != CURLE_OK:
                    if header_list:
                        curl_slist_free_all(header_list)
                    raise RuntimeError(f"Failed to set POST data: {curl_easy_strerror(res).decode('utf-8')}")

        # Follow redirects
        res = curl_easy_setopt(self.curl_ptr, CURLOPT_FOLLOWLOCATION, 1)
        if res != CURLE_OK:
            if header_list:
                curl_slist_free_all(header_list)
            raise RuntimeError(f"Failed to set follow redirects: {curl_easy_strerror(res).decode('utf-8')}")

        # Perform the request
        res = curl_easy_perform(self.curl_ptr)

        # Get status code
        cdef long response_code
        if res == CURLE_OK:
            res = curl_easy_getinfo(self.curl_ptr, CURLINFO_RESPONSE_CODE, &response_code)
            if res == CURLE_OK:
                self.status_code = response_code
        
        # Clean up headers
        if header_list:
            curl_slist_free_all(header_list)
        
        if res != CURLE_OK:
            raise RuntimeError(f"Request failed: {curl_easy_strerror(res).decode('utf-8')}")
        
        # Combine response data
        response_bytes = b"".join(self.response_data)
        
        return CurlResponse(
            status_code=self.status_code,
            data=response_bytes,
            headers=self.response_headers
        )
