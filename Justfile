pack:
    circleci orb pack ./src > orb.yml

publish: pack
    circleci orb publish orb.yml shadesmar/rust@0.1.5
