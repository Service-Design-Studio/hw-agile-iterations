A linter is a program that analyzes source code for common errors and conformance to a coding style.
When working in a team, it helps to have the repository conform to the same coding style.
For example, a specific team would like to have a specific template rendering system, say [erb](https://apidock.com/ruby/ERB) over [haml](http://haml.info/tutorial.html).
These standards tend to make a codebase consistent and hence easier to work with. 
Such decisions are made on a team-by-team basis and each team may have different preferences resulting in different styles being adopted.
Regardless of the final decision, teams tend to benefit overall from picking a standard or style and sticking by it.


You may have noticed that most of our HTML in [app/views](../app/views) is rendered using HAML. Our team decided to use it as it is more cross-platform,
that is, you can find HAML engines in more programming languages including Java, Javascript and PHP. This makes it easy for most developers to work with the codebase.


To enforce coding standards within this project, we have setup three different linter systems: [rubocop](https://github.com/rubocop-hq/rubocop), [haml-lint](https://github.com/sds/haml-lint) and [eslint](https://eslint.org/)
for Ruby files, HAML files and Javascript files respectively. In additions, you will notice there are configuration files [.rubocop.yml](../.rubocop.yml), [.haml-lint.yml](../.haml-lint.yml) and [.eslintrc.js](../.eslintrc.js) 
that list our codified standards for each linter system.


Run the following command to run rubocop lint checks:
```shell script
bundle exec rubocop
```

Run the following command to auto-correct some common rubocop lint errors:
```shell script
bundle exec rubocop -a
```

Run the following command to execute haml-lint checks:
```shell script
bundle exec haml-lint
```
Unfortunately, haml-lint does not yet have auto-correct functionality as of this writing.
See the following open github issue: [Autocorrect feature](https://github.com/sds/haml-lint/issues/217) issue.

Run the following command to execute eslint checks:
```shell script
yarn run lint_fix
```

Notice that we run eslint using `yarn run` command. If you check [package.json](../package.json), 
you will notice that `lint` and `lint_fix` are entries in JSON path `$.scripts.lint` and `$.scripts.lint_fix` that invoke a vendored install of eslint.

We have included tests that will enforce the linter checks in [spec/linters](../spec/linters).


Sometimes, you may just want to have a file watcher that runs linter check and tests as you work on the project.
[Guard](https://github.com/guard/guard) is a tool that allows you to run file watchers that run automated tasks whenever a file or directory is modified.
The [Guardfile](../Guardfile) specifies file watchers and tasks to run. To initiate guard, run the following command in a separate terminal:
```shell script
bundle exec guard
```

Next, you should read about Credentials management, GCP setup and CI Setup.
