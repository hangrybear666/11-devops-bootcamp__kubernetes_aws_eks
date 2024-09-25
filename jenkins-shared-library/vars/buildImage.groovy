#!/user/bin/env groovy

import com.example.Docker

def call(String repoUrl, String imageName, String imageVersion) {
    return new Docker(this).buildImage(repoUrl, imageName, imageVersion)
}
