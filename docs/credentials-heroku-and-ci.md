### Credentials Management
In past version of `rails`, credentials management has been done in a variety of ways.
There are gems that were used to push credentials and environment variables across environment (eg from localhost to heroku).
In this projects, we will be using built-in `config/credentials.yml.enc` in Rails 5.2. If you are working with legacy applications,
you may encounter `Figaro`, a popular gem that is used to manage credentials.
Note, for all the following commands, make sure to `cd` into the `path/to/your/rails_app` (not into the `app` directory, but it's parent!).

1. The first step to set up your own encrypted credentials is to delete the current `config/credentials.yml.enc`
    ```shell script
    rm -rf config/credentials.yml.enc
    ```

2. Then we need to regenerate a new `config/master.key` and `config/credentials.yml.enc`.
    ```shell script
    EDITOR=vim bundle exec rails credentials:edit
    ```
    Save and [exit vim](https://www.google.com/search?q=how+to+save+and+exit+vim) (using `escape` then `:wq`+`Enter`).

3. Take note of the `credentials.yml.enc` for now. It should look like the following.
   ```yaml
   .
   .
   .
   secret_key_base: some-long-string
   ```
4. Read [Part 4. Deploy to the cloud, including the production database.](https://github.com/Service-Design-Studio/hw-hello-rails/blob/master/Part4.md). Particularly, do the steps to Create a User. There is a step to generate a random password. You can also use other software to generate a random password for your Database. Edit and add the following:
   ```
   gcp:
    db_password: #YOUR DB PASSWORD#
   ```
5. Open a rails console with `bundle exec rails c`. Inside the console, you should be able to run the following command
   and see the secret_key_base from the file.
   ```ruby
   Rails.application.credentials[:secret_key_base]
   ```
   Rails.application.credentials.dig reads the given key eg 'GOOGLE_CLIENT_ID' from
   `config/credentials.yml.enc` by decrypting it with `config/master.key`.
   You could specify environment specific groups as follows in config/credentials.yml.enc:
   ```yaml
       production:
           GOOGLE_CLIENT_ID: xxxx
           GOOGLE_CLIENT_SECRET: xxx

       development:
           GOOGLE_CLIENT_ID: xxx
           GOOGLE_CLIENT_SECRET: xxx
   ```

   Then use the following syntax to read keys for specific environment:
   ```ruby
   Rails.application.credentials.dig(:production, :GOOGLE_CLIENT_ID)
   Rails.application.credentials.dig(:development, :GOOGLE_CLIENT_ID)
   ```
   (This step did not require you to change any files. It's simply an introduction of how to use credentials in Rails 5.)

### Google Cloud Platform (GCP)
Now we would like to setup the app on GCP ensuring that our credentials are available there.
1. Make sure you have installed GCP SDK. If not, follow the subsequent steps. Install GCP SDK client on your machine [using the following instructions](https://cloud.google.com/sdk/docs/install).

The command you should use is:
```shell script
curl -O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-355.0.0-linux-x86_64.tar.gz
tar xzvf google-cloud-sdk-355.0.0-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh
source ~/.bashrc
```
2. Make sure your installation works by running the following command `gcloud -v` to print the version of GCP SDK
   available on your terminal.
3. Log in to GCP using `gcloud init`.
4. Choose an existing project or create a new one.
5. Next you need to enable `PostgreSQL` on CloudSQL for your app. Follow the steps in [Part 4. Deploy to the cloud, including the production database.](https://github.com/Service-Design-Studio/hw-hello-rails/blob/master/Part4.md). Particularly, do the steps to Create CloudSQL Instance, Database, User and CloudBucket Storage.
6. You need to modify the file `config/database.yml` for the production environment. 
  ```
  production:
  <<: *postgresql
  database: #REPLACE WITH DATABASE NAME#
  username: #REPLACE WITH DATABASE USERNAME#
  password: <%= Rails.application.credentials.gcp[:db_password] %>
  host: '/cloudsql/#PROJECT_ID#:#REGION#:#CLOUDSQL_INSTANCE#'
  ```
  For the host, an example would look like something like the following.
  ```
  host: '/cloudsql/rottenpotatoes-323902:asia-southeast1:rotten-sql'
  ```
  Notice that `db_password` is the key set inside `config/credentials.yml.enc`. The command `Rails.application.credentials.gcp[:db_password]` reads the password inside the encrypted file using the master key in `config/master.key`. 
  
### Secret Manager

We will store the master key in the Cloud using Google's Secret Manager. Go to GCP Console and select Secret Manager.
1. On the top menu, click "Create Secret".
2. Enter `master-key` as the name.
3. Generate a secret key using `bundle exec rake secret` in your terminal and enter the secret value into the Secret Value. 
4. You can leave the rest of the options as default and click "Create Secret".

### Dockerfile and Cloud Build 

First, we will create a `Dockerfile` in the root directory. Copy the following code.
```
# Use the official lightweight Ruby image.
# https://hub.docker.com/_/ruby
FROM ruby:2.6.5 AS rails-toolbox

SHELL ["/bin/bash", "-c"]

RUN (curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.0/install.sh | bash)

# Install production dependencies.
WORKDIR /app

COPY Gemfile Gemfile.lock ./

RUN apt-get update && apt-get install -y libpq-dev && apt-get install -y python3-distutils-extra

RUN gem install bundler:1.17.3 && \
    bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle config set path vendor/bundle && \
    #bundle config set without production && \
    bundle install

# Copy local code to the container image.
COPY . /app

ENV RAILS_ENV=production
ENV RAILS_SERVE_STATIC_FILES=true
# Redirect Rails log to STDOUT for Cloud Run to capture
ENV RAILS_LOG_TO_STDOUT=true

# pre-compile Rails assets with master key
ARG RAILS_MASTER_KEY
RUN (source ~/.bashrc && nvm install 12.13.1 && npm install -g yarn@1.22.4 && RAILS_MASTER_KEY=${RAILS_MASTER_KEY} SECRET_KEY_BASE=1 bundle exec rake assets:precompile)

EXPOSE 8080

CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "8080"]
```

- We start using Ruby 2.6.5 as our Docker base image.
- Next, we change our shell to use `bash` instead in `SHELL ["/bin/bash", "-c"]`
- We then download `nvm`.
- The next line specifies the working directory to be `/app`. In the later part, we copy our files into `/app`. 
- The next few lines install some necessary packages and perform `bundle install`.
- We set a few environment variable using the `ENV` keyword.
- An imporant point is the `ARG` keyword where we supply the key `RAILS_MASTER_KEY`. This will be used in the cloud build.
- Next, we install `nvm`, `npm`, `yarn` and precompile the assets.
- The last two lines expose the port and run the webserver.

We also need to create `cloudbuild.yaml` in the root directory for Cloud Build submission and Cloud Run deployment. Copy the following and modify the relevant part.

```
# [START cloudrun_rails_cloudbuild]
steps:
  - id: "build image"
    name: "gcr.io/cloud-builders/docker"
    entrypoint: 'bash'
    args: ["-c", "docker build --build-arg RAILS_MASTER_KEY=$$RAILS_KEY -t gcr.io/${PROJECT_ID}/${_SERVICE_NAME} . "]
    secretEnv: ["RAILS_KEY"]

  - id: "push image"
    name: "gcr.io/cloud-builders/docker"
    args: ["push", "gcr.io/${PROJECT_ID}/${_SERVICE_NAME}"]

  - id: "apply create"
    name: "gcr.io/google-appengine/exec-wrapper"
    entrypoint: "bash"
    args:
        [
            "-c",
            "/buildstep/execute.sh -i gcr.io/${PROJECT_ID}/${_SERVICE_NAME} -s ${PROJECT_ID}:${_REGION}:${_INSTANCE_NAME} -e RAILS_MASTER_KEY=$$RAILS_KEY -- bundle exec rake db:create"
        ]
    secretEnv: ["RAILS_KEY"]

  - id: "apply migrations"
    name: "gcr.io/google-appengine/exec-wrapper"
    entrypoint: "bash"
    args:
          [
            "-c",
            "/buildstep/execute.sh -i gcr.io/${PROJECT_ID}/${_SERVICE_NAME} -s ${PROJECT_ID}:${_REGION}:${_INSTANCE_NAME} -e RAILS_MASTER_KEY=$$RAILS_KEY -- bundle exec rake db:migrate"
          ]
    secretEnv: ["RAILS_KEY"]

  - id: "apply seed"
    name: "gcr.io/google-appengine/exec-wrapper"
    entrypoint: "bash"
    args:
          [
            "-c",
            "/buildstep/execute.sh -i gcr.io/${PROJECT_ID}/${_SERVICE_NAME} -s ${PROJECT_ID}:${_REGION}:${_INSTANCE_NAME} -e RAILS_MASTER_KEY=$$RAILS_KEY -- bundle exec rake db:seed"
          ]
    secretEnv: ["RAILS_KEY"]

  - id: "run deploy"
    name: "gcr.io/google.com/cloudsdktool/cloud-sdk"
    entrypoint: gcloud
    args:
      [
        "beta", "run", "deploy",
        "${_SERVICE_NAME}",
        "--platform", "managed",
        "--region", "${_REGION}",
        "--image", "gcr.io/${PROJECT_ID}/${_SERVICE_NAME}:latest",
        "--add-cloudsql-instances", "${PROJECT_ID}:${_REGION}:${_INSTANCE_NAME}",
        "--allow-unauthenticated",
        "--memory", "1024M",
        "--update-secrets=RAILS_MASTER_KEY=${_SECRET_NAME}:latest"
      ]

availableSecrets:
  secretManager:
  - versionName: projects/${PROJECT_ID}/secrets/${_SECRET_NAME}/versions/latest
    env: RAILS_KEY

substitutions:
  _REGION: #REGION#
  _SERVICE_NAME: #CLOUDRUN_SERVICENAME#
  _INSTANCE_NAME: #CLOUDSQL_INSTANCE_NAME#
  _SECRET_NAME: #SECRET_NAME#

images:
  - "gcr.io/${PROJECT_ID}/${_SERVICE_NAME}:latest"
# [END cloudrun_rails_cloudbuild]
```

You will need to modify the section `substitutions` with your Google Cloud names and region. Now, let's describe the different steps in the `cloudbuild.yaml`:
- The first step is to build the container image. The command is similar to the previous exercise. The only change now is that we have the following arguments `--build-arg RAILS_MASTER_KEY=$$RAILS_KEY` where `RAILS_MASTER_KEY` is specified in the `Dockerfile` with `ARG RAILS_MASTER_KEY` line. This allows Google Cloud Secret Manager to supply the master key during the container image building. The value is specified from `$RAILS_KEY`.
- We have a new key-value pair whenever we want to use Google's Secret Manager. `secretEnv: ["RAILS_KEY"]`, where `RAILS_KEY` is also defined at the bottom of the file: 
    ```
    availableSecrets:
      secretManager:
      - versionName: projects/${PROJECT_ID}/secrets/${_SECRET_NAME}/versions/latest
        env: RAILS_KEY
    ```
- In this file, we also do the database creation, migration and seed using Cloud Build. In each of this step, we make use the secret key using:`-e RAILS_MASTER_KEY=$$RAILS_KEY`.
- For the `run deploy` step, we call `gcloud beta` which allows us to use `--update-secrets=RAILS_MASTER_KEY=${_SECRET_NAME}:latest`. 

Lastly, we need to modify `config/environments/production.rb` and uncomment the following line:
```
config.require_master_key = true
```

Once you are done, you can try to deploy by running:
```
gcloud builds submit --timeout=1h
```
It may take a while to do the database migration and seeding. That's why we put an option to increase the timeout limit to 1 hour. In the future, once the database is created and migrated, you can comment out those steps from `cloudbuild.yaml`. 

### Travis CI
1. Make sure you have an account with [travis-ci.com](https://travis-ci.com).
   Create the account with the Github account that you
   use for Github Classroom.
2. Install Travis CI CLI client on your terminal using the following command:
   ```shell script
   gem install travis
   ```

3. Login into Travis CI using your Github Credentials on the terminal:
   ```shell script
   travis login --pro --auto --github-token #YOUR_GITHUB_PERSONAL_TOKEN#
   ```

   If you get a `Bad Credentials` error, visit the `Travis CI - Common Issues` page listed in the menu.

   Afterwards, since we need to give Travis CI a means to clone our private repo to run CI builds,
   we need to generate an ssh-key for Travis to use. First identify your repo's org and name using:
   ```shell script
   git remote -v
   ```
   If the above command prints out something similar to the following:
   ```shell script
   origin  git@github.com:[myorg]/[myrepo].git
   ```
   Replace the `myorg` and `myrepo` below and run the command below.
   ```shell script
   travis sshkey --generate -r [myorg]/[myrepo]
   ```
   (Your command should look something like this:)
   ```shell script
   travis sshkey --generate -r cs169/hw-agile-iterations-fa20-000
   ```
   If you clone from your private repository, you will see something similar like the following:
   ```
   origin  https://github.com/[owner]/[myrepo].git 
   ```
   Replace the `myorg` and `myrepo` below and run the command below.
   ```shell script
   travis sshkey --generate -r [owner]/[myrepo]

   If you get a prompt that looks like `Store private key? |no|`, type `y`.

   If you get a prompt that looks like `Path: |id_travis_rsa|`, type `y`.
   
4. Go to [travis-ci.com](travis-ci.com). Click the + to add a new repo to Travis CI. Search for your repo name, and click on it to add it to Travis.

    ![](.guides/img/travis.png)

5. Navigate to your project page on Travis, and click More Options > Trigger Build.

6. Now push your `config/master.key` to Travis CI using:
   ```shell script
   travis encrypt --pro RAILS_MASTER_KEY="$(< config/master.key)" --add env
   ```

   If you see a message like `Detected repository as cs169/hw-agile-iterations-fa20-0909, is this correct?`, type `y`.

   After that, if you see a message like `Overwrite the config file /home/codio/workspace/hw-agile-iterations-fa20-0909/.travis.yml with the content below?`, type `y`.
   
7. You can set settings for the database either to use sqlite3 or postgres. If you use sqlite3, please see if the file `config/database.yml` contains the following lines.
   ```
   sqlite3: &sqlite3
      adapter: sqlite3
      pool: 5
      timeout: 5000
      
   test:
      <<: *sqlite3
      database: ":memory:"
   ```
   
8. You should edit `.travis.yml` to indicate the steps and the process.
   ```
   env:
  secure: <some long string>
  language: ruby
  dist: focal
  rvm:
  - 2.6.5
  cache:
    directories:
    - node_modules
    - vendor/bundle
  before_install:
  - gem install bundler:1.17.3
  - nvm install 12.13.1
  - npm install -g yarn@1.22.4
  before_script:
  - bundle install
  - yarn install
  script:
  - RAILS_ENV=test bundle exec rake db:create --trace
  - RAILS_ENV=test bundle exec rake db:migrate --trace
  - RAILS_ENV=test bundle exec rake db:seed --trace
  - bundle exec rspec
  - bundle exec cucumber
   ```

7. Then run the following command to ensure your `.travis.yml` file is valid.
   ```shell script
   travis lint
   ```

8. Add, commit and push to GitHub.

### Codecov
1. Head to [codecov.io](https://codecov.io) and Click `Students` in the navbar, then `Sign In with Github`.

2. Open your Personal Settings on CodeCov by clicking on your profile image in the top right corner. Ensure that you are a **Student**, and there is a box similar to the one below. If you do not see a box like that, follow the steps in the `CodeCov - Common Issues` page listed in the menu.

    ![](.guides/img/student.png)


3. Visit your repo on Codecov via `codecov.io/gh/[myorg]/[myrepo]/settings`. If you see a warning that says to `Add Private Scope`, go ahead and click that. If you see an `Activation Required` warning, follow the steps in the `CodeCov - Common Issues` page listed in the menu. If your repository is `Deactivated` click `Activate` button.

   Identify the `Repository Upload Token` and copy it.

4. Add this to your repo on Travis CI dashboard. In the project's Travis page, click `More Options` then `Settings`.
   Add the token to the `Environment Variables` section by pasting the Repository Upload Token you copied from CodeCov into the `Value` field, typing `CODECOV_TOKEN` in the `Name` field, and clicking `Add`. Turn on `Display Value in Build Log`.

5. Add and commit your changes on Codio, then push to Github. Head to [travis-ci.com](https://travis-ci.com)
   to try `Trigger Build` and test the CI pipeline. You should see a success message like the one below in your Travis Build log.

   ![](.guides/img/codecov_success.png)

6. Now replace the Travis and CodeCov badges in README.md.
   For Travis, if you click on the `build: ....` black and green badge next to your repo page on Travis, you will get option to
   copy the status image (in the `Result` box). Head over to your `README.md` file in your project repo, and modify the existing Travis badge to be yours instead.

   ![](.guides/img/travis-badge.png)

   For Codecov, [follow these instructions](https://stackoverflow.com/questions/54010651/codecov-io-badge-in-github-readme-md) to find your badge, and replace the existing badge in `README.md` just as you did for Travis.

Next, let's set up Pivotal Tracker.
