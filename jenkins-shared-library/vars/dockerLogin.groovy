#!/user/bin/env groovy

import com.example.Docker

def call(String username, String password) {
    return new Docker(this).dockerLogin(username, password)
}