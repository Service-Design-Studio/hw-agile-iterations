## How to setup your local development environment

### 0. Pull Staff changes

Clone your team's GitHub Classroom repository, and `cd` into the directory. Then, run the following commands:

```shell script
git remote add staff https://github.com/Service-Design-Studio/hw-agile-iterations.git
git pull staff master --allow-unrelated-histories
git remote remove staff
```

### 1. Install Ruby
You need to install Ruby. We recommend you use [rvm](https://rvm.io/) but you could also use [rbenv](https://github.com/rbenv/rbenv) to manage Ruby version.

These are environment management tools that help you switch between Ruby version easily across different projects.
Once you install one of these tools, you need to install the Ruby version listed in [Gemfile](../Gemfile).

First, run:
```shell script
gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
```

Then, the command to install `rvm` is:

```shell script
curl -sSL https://get.rvm.io | bash -s stable --ruby
```

After installing rvm or rbenv, you need to check that it is loaded in you current terminal. **Refresh Codio** at this point for your `rvm` installation to take effect.

You can do so by checking the version of your specific ruby env manager.
For example if you opt for rvm:
```shell script
rvm -v
```

Note, if rvm is not loaded you might want to reload your shell profile using:
```shell script
source ~/.bashrc
```

For example, if you are using rvm run the following commands.
```shell script
rvm install 2.6.5
rvm use 2.6.5
```

### 2. Install Node
Similarly, you need to install Node and we would recommend that you use [nvm](https://github.com/nvm-sh/nvm) which allows you to manage multiple active Node.js versions.

The command to install `nvm` is:

```shell script
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.37.0/install.sh | bash
```

After installing `nvm`, you need to check that it is loaded in you current terminal. **Refresh Codio** at this point for your `nvm` installation to take effect.

```shell script
source ~/.bashrc
```

The specific version of node you need to install is listed in [package.json](../package.json) under the [JSON path](https://github.com/json-path/JsonPath) `$.engines.node`.

Example use of nvm to install node version `12.13.1`:
```shell script
nvm install 12.13.1
```

### 3. Install Yarn
Once Node is installed, you need to install yarn. Node has two popular javascript package managers: [npm](https://github.com/npm/cli) and [yarn](https://github.com/yarnpkg/yarn).
In this project, we will use yarn as it is the default for [Rails Webpacker](https://github.com/rails/webpacker).
The specific version of yarn you need to install is listed in [package.json](../package.json) under the JSON path `$.engines.yarn`.

To install yarn run the following command, replacing `@1.22.4` with the version listed in package.json.
```shell script
npm install -g yarn@1.22.4
```

Next, run the following command to ensure you have the correct version of yarn installed.
```shell script
yarn -v
```

### 4. Install project dependencies
There are two sets of dependencies that you need to install: ruby dependencies and node dependencies.
First, to install ruby dependencies. [RubyGems](https://rubygems.org/) is a dependency management systems that allows developers to share and distribute code.

We recommend you install your ruby dependencies within the project's `vendor/bundle` folder instead globally within you ruby installation.
To do this, run the following command:
```shell script
bundle config set path vendor/bundle
```

The command above would imply that you will be required to run all ruby commands with the `bundle exec` prefix.
For example, to run a migration (which we will do shortly), you must execute the command `bundle exec rails db:migrate` instead of `rails db:migrate`.
Some may find this tedious, hence we suggest an option to alias the `bundle exec` prefix.
You could run `alias be="bundle exec"` on your terminal which will allow you to run `be rails db:migrate` instead of the more verbose `bundle exec rails db:migrate`.
You could add the alias to your shell profile eg. `~/.bashrc` to make it globally available.

For local development, we recommend you skip installing `production` dependencies by running the following command:
```shell script
bundle config set without production
```

Next, run the following command to install dependencies listed in the [Gemfile](../Gemfile).
A Gemfile is a file that list all of a Ruby project's dependencies.
The [Gemfile.lock](../Gemfile.lock) pins the dependencies listed in the Gemfile to specific versions alongside their specific transitive dependencies.
Pinning dependencies helps different developers working on the same project have reproducible builds.

First, install our desired version of the `bundler` gem, as well as installing a library that will allow us to use Postgres to install correctly. Run the following commands:
```shell script
gem install bundler:1.17.3
sudo apt-get install -y libpq-dev
```

The following command will install all the requirements in the `Gemfile.lock`.
It may take a while since some of the dependencies are Ruby extensions written in C, eg. Nokogiri.
```shell script
bundle install
```

After all the gems are installed, we now need to install the javascript requirements.
Node projects have a package.json file that serves the same purpose as Gemfile, but for Javascript dependencies. It lists all project dependencies.
[yarn.lock](../yarn.lock) and `package-lock.json` serve the same role as `Gemfile.lock`, they pin dependencies.
Yarn uses `yarn.lock` whereas npm uses `package-lock.json`. This project uses `yarn.lock` since it uses yarn.
Projects that use npm have `package-lock.json` instead. It is highly advised that you only have one of these and not both
in your project since they may diverge and lead to inconsistent environments for different developers.
You will notice that `package-lock.json` is git-ignored in [.gitignore](../.gitignore).

To install javascript requirements, we will ran the following command:
```shell script
yarn install
```

### 5. Run migrations and seed the database
Our app is almost ready for launch. You need to run database migrations in [db/migrate](../db/migrate) to prepare your localhost
database to store and serve data. To run migrations, execute the following command:
```shell script
bundle exec rails db:migrate
```
Note, you could use your alias `be rails db:migrate` if you opted to set it up.

Next, we need to seed our database with some data such as the list of states in the United States.
To do so, execute the following command:
```shell script
bundle exec rails db:seed
```

### 6. Launch the app!
Finally, it is time to launch the rails application and begin hacking away.
There are two ways to do this. The first option is that you could launch the application using the following bundle command.
```shell script
bundle exec rails s -b 0.0.0.0
```

However, this option has one major downside. It takes long for any changes that you make to reflect on the browser since
you will not have live reload.

The second option, is to have two terminals. In one terminal, run the following command:
```shell script
bin/webpack-dev-server
```

This will launch a `webpacker` instance that live reloads your browser as you edit the javascript code or CSS styles and makes the development process much faster.

After launching `webpack-dev-server` on one terminal, switch to the second terminal window and launch a rails server.
```shell script
bundle exec rails s -b 0.0.0.0
```

Next, you should read about linters.
