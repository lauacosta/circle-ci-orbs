pack:
    circleci orb pack ./src > orb.yml

publish: pack
    circleci orb publish orb.yml shadesmar/rust@dev:alpha

validate:
    circleci config validate .circleci/config.yml
    circleci config validate .circleci/test-deploy.yml
