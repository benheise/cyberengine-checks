# Introduction

Cyberengine is the combination of a Ruby on Rails web front-end and backend service checks. Cyberengine is designed to check and score common network services used in "blueteam-redteam-whiteteam" competitions and provide a web interface for teams about their servers and services.


## Setup Overview

* There are many **Teams** of type _white_, _red_, and _blue_
* A team can have many **Members** 
* **Teams** have many **Servers**
* **Servers** have many **Services** each defining a _protocol_ (dns, ftp, ssh...) and _version_ (ipv4 or ipv6) 
* **Services** have many **Properties** that outline how the **Service** will be checked
* **Properties** include the _address_, timeout period, options, and random options for checks
* **Services** can have many **Users** that have a _username_/ _password_ and are randomly selected in checks
* **Services** have many **Checks** that are _pass_ or _fail_ and provide information about the request/response


## Cyberengine Checks Installation Process 
### Tested on a minimal Fedora 17 installation (must be root)

1. Disable selinux
```bash
# Disable selinux
echo 'SELINUX=disabled' >> /etc/selinux/config
# Dont need iptables messing things up for now
systemctl stop iptables.service
systemctl disable iptables.service
reboot
```

2. Install all required packages for: checks, rvm/ruby, database, and apache
```bash
# Basic/Checks
yum install -y bash tar git curl curl-devel vim bind-utils iputils iproute
# RVM/Ruby (copied from: rvm requirements) 
yum install -y gcc-c++ patch readline readline-devel zlib zlib-devel libyaml-devel libffi-devel openssl-devel make bzip2 autoconf automake libtool bison iconv-devel
# Database
yum install -y postgresql postgresql-devel
```

3. Install ruby (version >= 1.9.3) via Ruby Version Manager (RVM) - https://rvm.io/rvm/install
```bash
curl -kL https://get.rvm.io | bash -s stable
source /etc/profile.d/rvm.sh
rvm install 1.9.3 --verify-downloads 1
rvm use 1.9.3 --default
# Answer yes to any 'cp: overwrite' options
```

4. Download cyberengine checks and install gems (libraries)
```bash
cd /var
git clone -v https://github.com/griffithchaffee/cyberengine-checks.git
# If you dont do this you may get permission errors
cd cyberengine-checks
# Do you wish to trust this .rvmrc file? (/root/cyberengine/.rvmrc)
# y[es], n[o], v[iew], c[ancel]> yes
bundle install
# Set correct database configuration options
vi database.yml # COMMENT OUT UNUSED ENVIRONMENTS
```

## Checks

### Basics
* Checks are identified by their path
* version/protocol/check
* The cyberengine executable is a fully functional wrapper that makes it easy to stop/start enable/disable checks
* Checks can be run in the forground or as daemons. As a daemon they log to their log file and can be terminated by sending the TERM signal.


### Usage

* Getting information

```bash
./cyberengine help
Syntax: cyberengine.rb <command> <check> <check>...

<check>:
all => match all checks
ipv4/icmp/ping => match ipv4/icmp/ping check only

<command>:
disable => Disable checks
disabled => Show disabled checks
enable => Enable checks
enabled => Show enabled checks
errors => Show errors
help => Show help text
list => Show all checks and enabled/disabled status
logs => Print all log files
pids => Print all pid files
start => Start checks
status => Show running checks
stop => Stop checks
tail => Tail check log file
test => Start check in test mode

./cyberengine list
Enabled : ipv4/dns/domain-query
Enabled : ipv4/ftp/download
Enabled : ipv4/ssh/login
...

./cyberengine enable ipv4/ssh/login
```

* Start checks

```bash
./cyberengine list
./cyberengine enable all
./cyberengine start ipv4/ssh/login
```

* Testing checks (no checks will be saved)

```bash
./cyberengine test ipv4/ssh/login
```

* Stopping checks

```bash
./cyberengine status
./cyberengine stop ipv4/ssh/login # Check will stop at end of round
# Optional way to stop the service
kill -s TERM <pid>
```

* You can check for errors or watch log files


```bash
./cyberengine errors ipv4/ssh/login
./cyberengine tail ipv4/ssh/login
```

* All macro makes it easy to do mass changes
* No argument equals all

```bash
./cyberengine enable all
./cyberengine enable # Same as above
./cyberengine enabled
```

## Check Options

### Properties

* Defaults defined on whiteteam
* Individual team options override whiteteam options
* Properties always lowercase and hyphen delimiters - Example: Send Mail = send-mail

#### Property Categories

```bash
# There are four property categories
# Defines a service address (each check will be run against all addresses)
category: 'address'
# Defines a unique service property (DNS query type: A vs AAAA vs PTR)
category: 'option'
# Defines an property with many options (HTTP useragents)
category: 'random'
# Defines a property used to check for success/failure of a check
category: 'answer'
# Defines a property used temporarily (mostly in mobility)
category: 'temp'
```


#### Defaults
* All defaults are defined under whiteteam. These defaults are used if they are not defined for a team. The most common example is the timeout property which specifies after how many seconds a check should be cancled.
* Typically answer properties are also defined at the whiteteam level but can be overridden per team. There are two common types of answer properties: full-text-regex and each-line-regex. If either of these match the check is deemed to pass. DNS is one service that does not use this, instead domain answers are defined on a per team level.
* Majority of checks use unix command line tools such as curl. This is to make it easier to debug. While many could be completly written using a language library, it would be difficult to troubleshoot errors for both blueteams and whiteteam.


## Mobility

#### IPV4 Mobility

* ipv4/none/mobility
* This is not a service check and is only defined for whiteteam. This service is used to configure random source ipv4 addresses. A new address is added to an alias interface based on properties. For this address to be used routes must be provided. Each route will be assigned with the src option set to the new ip.

#### Service

```bash
name: "IPV4 Mobility", version: 'ipv4', protocol: 'none'
```

#### Properties

```bash
category: 'random', property: 'address-range' # Range to pick random address from: 192.168.1.1-20/24 (sample address would be: 192.168.1.5/24)
category: 'option', property: 'interface' # Interface to add the random address on
category: 'option', property: 'dad_test' # Test used to see if arping failed
category: 'option', property: 'route' # Each route option will be pulled and updated each time a new address is selected. A value of 'default' means the route is an IP and the default gateway.
category: 'option', property: 'delay' # Delay between address changes
```


## Available Checks ##

### DNS Domain Query

* ipv4/dns/domain-query

#### Service

```bash
name: "DNS Domain Query", version: 'ipv4', protocol: 'dns'
```

#### Properties

```bash
category: 'address'
category: 'option', property: 'timeout'
category: 'option', property: 'query-type' # A, AAAA, PTR
category: 'random', property: 'query' # Example value: 'google-public-dns-a.google.com'
# Answer option not required if using resolves-to-address option below
category: 'answer', property: '<query-property>' # Example property: google-public-dns-a.google.com', value: '8.8.8.8'
# Optional
category: 'option', property: 'resolves-to-address' # enabled/disabled - Used if just want to check that IP resolves and dont care what it resolves to
category: 'option', property: 'resolves-to-address-regex' # Regex used to check answers and usually matches ip addresses
```

### FTP Download

* ipv4/ftp/download

#### Service

```bash
name: "FTP Download", version: 'ipv4', protocol: 'ftp'
```

#### Properties

```bash
# Uses random user
# Macro: $USER replaced with current user
category: 'address'
category: 'option', property: 'timeout'
category: 'option', property: 'filename' # file the check attempts to download. Can be a path such as /var/log/messages
category: 'answer', property: 'each-line-regex'
category: 'answer', property: 'full-text-regex'
```

### FTP Upload

* ipv4/ftp/upload

#### Service

```bash
name: "FTP Upload", version: 'ipv4', protocol: 'ftp'
```

#### Properties

```bash
# Uses random user
# Macro: $USER replaced with current user
category: 'address'
category: 'option', property: 'timeout'
category: 'option', property: 'filename' # file the check attempts to upload
category: 'option', property: 'filename-timestamp' # disabled = no filename timestamp
category: 'answer', property: 'each-line-regex'
category: 'answer', property: 'full-text-regex'
```

### FTPS Download

* ipv4/ftps/download

#### Service

```bash
name: "FTPS Download", version: 'ipv4', protocol: 'ftps'
```

#### Properties

```bash
# Uses random user
# Macro: $USER replaced with current user
category: 'address'
category: 'option', property: 'timeout'
category: 'option', property: 'filename' # file the check attempts to download. Can be a path such as /var/log/messages
category: 'answer', property: 'each-line-regex'
category: 'answer', property: 'full-text-regex'
```

### FTPS Upload

* ipv4/ftps/upload

#### Service

```bash
name: "FTPS Upload", version: 'ipv4', protocol: 'ftps'
```

#### Properties

```bash
# Uses random user
# Macro: $USER replaced with current user
category: 'address'
category: 'option', property: 'timeout'
category: 'option', property: 'filename' # file the check attempts to upload
category: 'option', property: 'filename-timestamp' # disabled = no filename timestamp
category: 'answer', property: 'each-line-regex'
category: 'answer', property: 'full-text-regex'
```

### HTTP Available

* ipv4/http/available

#### Service

```bash
name: "HTTP Available", version: 'ipv4', protocol: 'http'
```

#### Properties

```bash
category: 'address'
category: 'option', property: 'timeout'
category: 'random', property: 'useragent'
category: 'random', property: 'uri' # Appended to end of address to form URL
category: 'answer', property: 'each-line-regex'
category: 'answer', property: 'full-text-regex'
```
 
### HTTP Content

* ipv4/http/available

#### Service

```bash
name: "HTTP Content", version: 'ipv4', protocol: 'http'
```

#### Properties

```bash
category: 'address'
category: 'option', property: 'timeout'
category: 'random', property: 'useragent'
category: 'random', property: 'uri' # Appended to end of address to form URL
category: 'answer', property: 'each-line-regex'
category: 'answer', property: 'full-text-regex'
```
 
### HTTPS Available

* ipv4/https/available

#### Service

```bash
name: "HTTPS Available", version: 'ipv4', protocol: 'https'
```

#### Properties

```bash
category: 'address'
category: 'option', property: 'timeout'
category: 'random', property: 'useragent'
category: 'random', property: 'uri' # Appended to end of address to form URL
category: 'answer', property: 'each-line-regex'
category: 'answer', property: 'full-text-regex'
```
 
### HTTPS Content

* ipv4/https/available

#### Service

```bash
name: "HTTPS Content", version: 'ipv4', protocol: 'https'
```

#### Properties

```bash
category: 'address'
category: 'option', property: 'timeout'
category: 'random', property: 'useragent'
category: 'random', property: 'uri' # Appended to end of address to form URL
category: 'answer', property: 'each-line-regex'
category: 'answer', property: 'full-text-regex'
```

### ICMP Ping

* ipv4/icmp/ping

#### Service

```bash
name: "ICMP Ping", version: 'ipv4', protocol: 'icmp'
```

#### Properties

```bash
category: 'address'
category: 'option', property: 'timeout'
category: 'answer', property: 'each-line-regex'
category: 'answer', property: 'full-text-regex'
```

### IRC Channel Join

* ipv4/irc/channel-join

#### Service

```bash
name: "IRC Channel Join", version: 'ipv4', protocol: 'irc'
```

#### Properties

```bash
# Random user picked for nickname/realname
category: 'address'
category: 'option', property: 'timeout'
category: 'option', property: 'authentication' # enabled/disabled, PASS command used if enabled
category: 'random', property: 'channel'
category: 'option', property: 'port'
category: 'answer', property: 'each-line-regex'
category: 'answer', property: 'full-text-regex'
```

#### POP3 Login

* ipv4/pop3/login

#### Service

```bash
name: "POP3 Login", version: 'ipv4', protocol: 'pop3'
```

#### Properties

```bash
# Uses random user
category: 'address'
category: 'option', property: 'timeout'
category: 'answer', property: 'each-line-regex'
category: 'answer', property: 'full-text-regex'
```

#### POP3S Login

* ipv4/pop3s/login

#### Service

```bash
name: "POP3S Login", version: 'ipv4', protocol: 'pop3s'
```

#### Properties

```bash
# Uses random user
category: 'address'
category: 'option', property: 'timeout'
category: 'answer', property: 'each-line-regex'
category: 'answer', property: 'full-text-regex'
```

#### SMTP Send Mail

* ipv4/smtp/send-mail

#### Service

```bash
name: "SMTP Send Mail", version: 'ipv4', protocol: 'smtp'
```

#### Properties

```bash
# Uses random user
category: 'address'
category: 'option', property: 'timeout'
category: 'random', property: 'from-domain'
category: 'answer', property: 'each-line-regex'
category: 'answer', property: 'full-text-regex'
# Optional
category: 'random', property: 'rcpt-user' # Defaults to random user
category: 'random', property: 'rcpt-domain' # Defaults to from-domain
category: 'random', property: 'from-user' # Defaults to random user
```

#### SMTPS Send Mail

* ipv4/smtps/send-mail

#### Service

```bash
name: "SMTPS Send Mail", version: 'ipv4', protocol: 'smtps'
```

#### Properties

```bash
# Uses random user
category: 'address'
category: 'option', property: 'timeout'
category: 'random', property: 'from-domain'
category: 'answer', property: 'each-line-regex'
category: 'answer', property: 'full-text-regex'
# Optional
category: 'random', property: 'rcpt-user' # Defaults to random user
category: 'random', property: 'rcpt-domain' # Defaults to from-domain
category: 'random', property: 'from-user' # Defaults to random user
```
 
#### SSH Login

* ipv4/ssh/login

#### Service

```bash
name: "SSH Login", version: 'ipv4', protocol: 'ssh'
```

#### Properties

```bash
# Uses random user
# Macro: $USER replaced with current user
category: 'address'
category: 'option', property: 'timeout'
category: 'random', property: 'command' # command to execute upon logging in
category: 'answer', property: 'each-line-regex'
category: 'answer', property: 'full-text-regex'
```

## License
Cyberengine is released under the [MIT License](http://www.opensource.org/licenses/MIT)
