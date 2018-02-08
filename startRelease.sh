#!/bin/bash
#Setup the release
#VERSION=$(echo $(git describe) | cut -d "-" -f 1)
VERSION=1.1.1

echo $VERSION

echo $PYPI_USER


echo "Checking requested release version string"

#Check if the requested version is "x.y.z"
if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: Version string did not match \"^[0-9]+\.[0-9]+\.[0-9]+$\""
    exit 1
fi

#Check if the requested version has already been released
tag=$(git ls-remote --tags origin ${VERSION})
if [[ $? != 0 ]]; then
    echo "ERROR: Command \"git ls-remote --tags origin ${VERSION}\" failed"
elif [[ $tag ]]; then
    echo "ERROR: Version string already found"
    exit 1
fi

echo "Sorting release notes"

#Setting version and date on release notes
sed --in-place "s/@VERSION@/${VERSION} (`date '+%Y\/%m\/%d'`)/g" release/ReleaseNotes

#Copying release notes
git mv release/ReleaseNotes release/ReleaseNotes-${VERSION}

#Creating new release notes from template
cat << EOF > release/ReleaseNotes
**************************************************************************************************************
@VERSION@


--------------------------------------------------------------------------------------------------------------
ganga/python/Ganga
--------------------------------------------------------------------------------------------------------------
* ...

**************************************************************************************************************
EOF
git add release/ReleaseNotes
git add release/ReleaseNotes-${VERSION}

#Committing changes
git commit -m "Updating release notes"

echo "Changing version numbers"

#Setting version number and turn off DEV flag
#sed --in-place "s/^_gangaVersion = .*/_gangaVersion = '\$Name: ${VERSION} \$'/g" python/Ganga/__init__.py
sed --in-place "s/^_gangaVersion = .*/_gangaVersion = '${VERSION}'/g" python/GangaCore/__init__.py
sed --in-place "s/^_gangaVersion = .*/_gangaVersion = '${VERSION}'/g" ./setup.py
sed --in-place "s/^_development = .*/_development = False/g" python/GangaCore/__init__.py
git add python/GangaCore/__init__.py ./setup.py

#Committing changes
git commit -m "Setting release number"

echo "Creating tag $VERSION"
#Now create a tag and fire it at github
git tag -a $VERSION

#echo "Pushing to origin"
git push  --tags

#Now send the release notes to github - need some python magic
echo "Creating new release on github"
function sendReleaseNotes {
version=$VERSION apitoken=$GITHUBAPITOKEN python - <<END
import requests
import json
import os

version = os.environ.get('version')

changelog = open('release/ReleaseNotes-'+version, 'r').readlines()
changelog = changelog[4:-2]  # Strip headings...?
changelog = ''.join(changelog)

release = {
  'tag_name': version,
  'target_commitish': 'master',
  'name': version,
  'body': changelog,
  'draft': False,
  'prerelease': False
}

r = requests.post('https://api.github.com/repos/ganga-devs/ganga/releases', data=json.dumps(release), headers={'Authorization':'token %s'  % os.environ.get('apitoken')})

r.raise_for_status()
END
}

sendReleaseNotes

#Below is the necessaries for the pypi upload. Maybe best done somewhere else

#pip install --upgrade pip
#pip install --upgrade twine

#cat << EOF > ~/.pypirc
#[distutils]
#index-servers =
#    pypi

#[pypi]
#The repository line is apparently outdated now
#repository = https://pypi.python.org/pypi/
#username: $PYPI_USER
#password: $PYPI_PASSWORD
#EOF

#python setup.py register
#python setup.py sdist
#twine upload --skip-existing dist/ganga-*.tar.gz

#rm dist/ganga-*.tar.gz
#rm ~/.pypirc


#All done!
