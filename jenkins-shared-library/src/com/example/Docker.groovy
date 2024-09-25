package com.example

class Docker implements Serializable {

    def script

    Docker(script) {
        this.script = script
    }

    // function parameters are passed from within Jenkinsfile initially, to demonstrate dynamic method invokation.
    // Env Vars are exposed via passing 'this' from the original groovy scripts in /vars folder
    def buildImage(String repoUrl, String imageName, String imageVersion) {
        script.echo "building the docker image: $imageName-$imageVersion ..."
        script.sh "docker build -t $repoUrl:$imageName-$imageVersion ."
    }

    def dockerLogin(String username, String password) {
        script.sh "echo '$password' | docker login -u '$username' --password-stdin"
    }

    def dockerPush(String repoUrl, String imageName, String imageVersion) {
        script.sh "docker push $repoUrl:$imageName-$imageVersion"
    }

}