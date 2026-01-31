## STEP 1 - Update package index
```bash
sudo apt update
```

## STEP 2 - Install required system tools
```bash
sudo apt install ca-certificates curl gnupg lsb-release
```

- ca-certificates -> certification tool that allows secure HTTPS downloads
- curl -> downloads files from the internet
- gnupg -> verifies software authenticity using cryptographic signatures. (Software that uses GPG = GNU Privacy Guard)
- lsb-release -> tells Debian which version it is

## STEP 3 - Create a place to store trusted keys
```bash
sudo mkdir -p /etc/apt/keyrings
```

## STEP 4 - Add Docker’s official GPG key (for Debian!)
```bash
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```
Flags:
-f -> fail on error
-s -> silent
-S -> show errors
-L -> follow redirects
-gpg --dearmor
    Converts the downloaded text key into a binary format
    Debian’s package manager requires this format
-o /etc/apt/keyrings/docker.gpg
    Saves the converted key to a secure system location
    This file will later be used by apt to verify Docker packages

- Downloads Docker’s public signing key
- Converts it to a binary format required by APT
- Stores it securely for later package verification

Check it worked:
```bash
ls -l /etc/apt/keyrings/docker.gpg
file /etc/apt/keyrings/docker.gpg
```
expected output:
GPG key public ring

## STEP 5 - Add Docker’s repository
```bash
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```
echo "deb ... stable"
    - Creates a repository definition line.
    - deb -> saying those are binary packages in the APT configuration file
    - arch=amd64 -> 64-bit systems only
    - signed-by=... -> trusted only by the Docker’s key that we downloaded
    - the URL -> where Docker packages live
    - $(lsb_release -cs) -> inserts the Debian codename
    - stable -> Docker’s stable release channel

sudo tee /etc/apt/sources.list.d/docker.list
    - tee writes input to a file
    - This safely creates a new repository file

/dev/null
    - throw output(only) to trash

## STEP 6 - Update again
```bash
sudo apt update
```

## STEP 7 - Install Docker
```bash
sudo apt install docker-ce docker-ce-cli containerd.io docker-compose-plugin
```
| Package                 | What it is        | Role                   |
| ----------------------- | ----------------- | ---------------------- |
| `containerd.io`         | Container runtime | Runs containers        |
| `docker-ce`             | Docker daemon     | Manages containers     |
| `docker-ce-cli`         | Docker command    | User interface         |
| `docker-compose-plugin` | Compose tool      | Multi-container setups |


Verification:
```bash
sudo docker --version
sudo docker run hello-world
```