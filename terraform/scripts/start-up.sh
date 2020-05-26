#cloud-config
write_files:
- path: /config/cloud/s3GetPackages.py
  permissions: '0755'
  content: |
        # See: http://docs.aws.amazon.com/general/latest/gr/sigv4_signing.html
        # See: https://docs.aws.amazon.com/general/latest/gr/sigv4-signed-request-examples.html
        # This version makes a GET request and passes the signature
        # in the Authorization header.
        import sys, os, base64, datetime, hashlib, hmac
        import requests
        from urlparse import urlparse

        # ************* REQUEST VALUES *************
        s3Url =  os.environ.get('S3BUCLOCATION')
        parseds3Url = urlparse(s3Url)
        s3UrlHost = parseds3Url.hostname
        s3Urlpath = parseds3Url.path
        method = 'GET'
        service = 's3'
        request_parameters = ''
        payload_hash = hashlib.sha256(('').encode('utf-8')).hexdigest()

        # Key derivation functions. See:
        # http://docs.aws.amazon.com/general/latest/gr/signature-v4-examples.html#signature-v4-examples-python
        def sign(key, msg):
          return hmac.new(key, msg.encode('utf-8'), hashlib.sha256).digest()

        def getSignatureKey(key, dateStamp, regionName, serviceName):
          kDate = sign(('AWS4' + key).encode('utf-8'), dateStamp)
          kRegion = sign(kDate, regionName)
          kService = sign(kRegion, serviceName)
          kSigning = sign(kService, 'aws4_request')
          return kSigning

        # Read AWS access key from env. variables or configuration file. Best practice is NOT
        # to embed credentials in code.
        access_key = os.environ.get('AWS_ACCESS_KEY_ID')
        secret_key = os.environ.get('AWS_SECRET_ACCESS_KEY')
        token = os.environ.get('AWS_TOKEN')
        region = os.environ.get('AWS_REGION')

        if access_key is None or secret_key is None or token is None:
          print('No access key, secret key, or token  is available.')
          sys.exit()

        # Create a date for headers and the credential string
        t = datetime.datetime.utcnow()
        amzdate = t.strftime('%Y%m%dT%H%M%SZ')
        datestamp = t.strftime('%Y%m%d') # Date w/o time, used in credential scope


        # ************* TASK 1: CREATE A CANONICAL REQUEST *************
        # http://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html

        # Step 1 is to define the verb (GET, POST, etc.)--already done.

        # Step 2: Create canonical URI--the part of the URI from domain to query
        # string (use '/' if no path)
        canonical_uri = s3Urlpath

        # Step 3: Create the canonical query string. In this example (a GET request),
        # request parameters are in the query string. Query string values must
        # be URL-encoded (space=%20). The parameters must be sorted by name.
        # For this example, the query string is pre-formatted in the request_parameters variable.
        canonical_querystring = request_parameters

        # Step 4: Create the canonical headers and signed headers. Header names
        # must be trimmed and lowercase, and sorted in code point order from
        # low to high. Note that there is a trailing \n.
        canonical_headers = 'host:' + s3UrlHost + '\n' + 'x-amz-content-sha256:' + payload_hash + '\n'+ 'x-amz-date:'+ \
        amzdate + '\n' + 'x-amz-security-token:' + token + '\n'

        # Step 5: Create the list of signed headers. This lists the headers
        # in the canonical_headers list, delimited with ";" and in alpha order.
        # Note: The request can include any headers; canonical_headers and
        # signed_headers lists those that you want to be included in the
        # hash of the request. "Host" and "x-amz-date" are always required.
        signed_headers = 'host;x-amz-content-sha256;x-amz-date;x-amz-security-token'

        # Step 6: Create payload hash (hash of the request body content). For GET
        # requests, the payload is an empty string ("").
        payload_hash = hashlib.sha256(('').encode('utf-8')).hexdigest()
        print(payload_hash)

        # Step 7: Combine elements to create canonical request
        canonical_request = method + '\n' + canonical_uri + '\n' + canonical_querystring + '\n' + canonical_headers \
        +'\n' + signed_headers + '\n' + payload_hash

        # ************* TASK 2: CREATE THE STRING TO SIGN*************
        # Match the algorithm to the hashing algorithm you use, either SHA-1 or
        # SHA-256 (recommended)
        algorithm = 'AWS4-HMAC-SHA256'
        credential_scope = datestamp + '/' + region + '/' + service + '/' + 'aws4_request'
        string_to_sign = algorithm + '\n' +  amzdate + '\n' +  credential_scope + '\n' + \
        hashlib.sha256(canonical_request.encode('utf-8')).hexdigest()

        #print('String to Sign: ' + string_to_sign)

        # ************* TASK 3: CALCULATE THE SIGNATURE *************
        # Create the signing key using the function defined above.
        signing_key = getSignatureKey(secret_key, datestamp, region, service)

        # Sign the string_to_sign using the signing_key
        signature = hmac.new(signing_key, (string_to_sign).encode('utf-8'), hashlib.sha256).hexdigest()

        authorization_header = algorithm + ' ' + 'Credential=' + access_key + '/' + credential_scope + ', ' + \
        'SignedHeaders=' + signed_headers + ', ' + 'Signature=' + signature

        headers = {'x-amz-content-sha256':payload_hash,'x-amz-date':amzdate, 'Authorization':authorization_header, \
          'x-amz-security-token':token}


        # ************* SEND THE REQUEST *************
        request_url = s3Url

        print('\nBEGIN REQUEST++')
        print('Request URL = ' + request_url)
        r = requests.get(request_url, headers=headers)

        print('\nRESPONSE+++++++')
        print('Response code: %d\n' % r.status_code)
        r.content
        print('\n saving to /config/cloud/dependencies' + str(s3Urlpath))
        open('/config/cloud/dependencies' + s3Urlpath, 'wb').write(r.content)

- path: /config/cloud/startup-script.sh
  permissions: '0755'
  content: |
    #!/bin/bash

    ## 1NIC BIG-IP ONBOARD SCRIPT

    ## IF THIS SCRIPT IS LAUNCHED EARLY IN BOOT (ex. when from cloud-init),
    # YOU NEED TO RUN IT IN THE BACKGROUND TO NOT BLOCK OTHER STARTUP FUNCTIONS
    # ex. location of interpolated cloud-init script
    #/opt/cloud/instances/i-079ac8a174eb1727a/scripts/part-001

    LOG_FILE=/var/log/startup-script.log
    if [ ! -e $LOG_FILE ]
    then
      touch $LOG_FILE
      exec &>>$LOG_FILE
      # nohup $0 0<&- &>/dev/null &
    else
      #if file exists, exit as only want to run once
      exit
    fi

    ### ONBOARD INPUT PARAMS

    #region=${region}
    adminUsername=${admin_username}
    adminPassword=${admin_password}
    #terraform does not need $() escaped
    hostname=$(curl --silent --fail --retry 20 http://169.254.169.254/latest/meta-data/hostname)
    dnsServer=${dns_server}
    ntpServer=${ntp_server}
    timezone=${timezone}
    dnsResolver=${dns_resolver}
    sslCertName=${sslcertname}

    # Management Interface uses DHCP
    # v13 uses mgmt for ifconfig & defaults to 8443 for GUI for Single Nic Deployments
    if ifconfig mgmt; then managementInterface=mgmt; else managementInterface=eth0; fi
    managementAddress=$(egrep -m 1 -A 1 $managementInterface /var/lib/dhclient/dhclient.leases | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}')
    managementGuiPort=${managementGuiPort}

    ### CREATING LIBS $ DIRECTORY
    libs_dir="/config/cloud/aws/node_modules/f5devcentral"
    mkdir -p $libs_dir
    dep_dir="/config/cloud/dependencies"
    mkdir -p $dep_dir
    ### S3 bucket folders have to be mapped for the python script
    dep_conf="config/cloud/dependencies/configuration"
    mkdir -p $dep_conf
    dep_pol="config/cloud/dependencies/policy"
    mkdir -p $dep_pol

    ### GET AWS VARIABLES
    echo "!!!!! GETTING VARIABLES FROM EC2 METADATA API: ROLENAME, ACCESSKEY, ACCESSSECRET,TOKEN, REGION"
    role_name=$(curl -s "http://169.254.169.254/latest/meta-data/iam/security-credentials/" )
    payload=$(curl -s http://169.254.169.254/latest/meta-data/iam/security-credentials/$role_name)
    export AWS_ACCESS_KEY_ID=$(printf "$payload" | jq -r ".AccessKeyId")
    export AWS_SECRET_ACCESS_KEY=$(printf "$payload" | jq -r ".SecretAccessKey")
    export AWS_TOKEN=$(printf "$payload" | jq -r ".Token")
    export AWS_REGION=`curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone| sed s/.$//`

    ### DOWNLOADING DEPENDENCIES
    #@TODO: Leonardo suggests that we should put the rpms and tars file name in a variable for changes and updates.

    echo "!!!!! Using python script getting f5-cloud-libs.tar.gz !!!!!"
    export S3BUCLOCATION='https://${bucket_name}.s3.${region}.amazonaws.com/configuration/f5-cloud-libs.tar.gz'
    python /config/cloud/s3GetPackages.py

    echo "!!!!! Using python script getting f5-cloud-libs-aws.tar.gz !!!!!"
    export S3BUCLOCATION='https://${bucket_name}.s3.${region}.amazonaws.com/configuration/f5-cloud-libs-aws.tar.gz'
    python /config/cloud/s3GetPackages.py

    echo "!!!!! Using python script getting ${do_rpm} !!!!!"
    export S3BUCLOCATION='https://${bucket_name}.s3.${region}.amazonaws.com/configuration/${do_rpm}'
    python /config/cloud/s3GetPackages.py

    echo "!!!!! Using python script getting ${as3_rpm}!!!!!"
    export S3BUCLOCATION='https://${bucket_name}.s3.${region}.amazonaws.com/configuration/${as3_rpm}'
    python /config/cloud/s3GetPackages.py

    echo "!!!!! Using python script getting ${ts_rpm} !!!!!"
    export S3BUCLOCATION='https://${bucket_name}.s3.${region}.amazonaws.com/configuration/${ts_rpm}'
    python /config/cloud/s3GetPackages.py

    echo "!!!!! Using python script getting SSL_FORWARD_PROXY.crt !!!!!"
    export S3BUCLOCATION=https://${bucket_name}.s3.${region}.amazonaws.com/policy/$${sslCertName}.crt
    python /config/cloud/s3GetPackages.py

    echo "!!!!! Using python script getting SSL_FORWARD_PROXY.key !!!!!"
    export S3BUCLOCATION=https://${bucket_name}.s3.${region}.amazonaws.com/policy/$${sslCertName}.key
    python /config/cloud/s3GetPackages.py

    echo "!!!!! Using python script getting DO_DeclarationExplicitProxy.json !!!!!"
    export S3BUCLOCATION='https://${bucket_name}.s3.${region}.amazonaws.com/policy/DO_DeclarationExplicitProxy.json'
    python /config/cloud/s3GetPackages.py

    echo "!!!!! Using python script getting TS_DeclarationExplicitProxy.json !!!!!"
    export S3BUCLOCATION='https://${bucket_name}.s3.${region}.amazonaws.com/policy/TS_DeclarationExplicitProxy.json'
    python /config/cloud/s3GetPackages.py

    echo "!!!!! Using python script getting as3_DeclarationExplicitProxy.json !!!!!"
    export S3BUCLOCATION='https://${bucket_name}.s3.${region}.amazonaws.com/policy/as3_DeclarationExplicitProxy.json'
    python /config/cloud/s3GetPackages.py

    ### UNPACKAGING LIBS
    echo "!!!!! unpacking f5-cloudlibs and f5-cloud-libs-aws"
    tar xvfz /config/cloud/dependencies/configuration/f5-cloud-libs.tar.gz -C $libs_dir
    tar xvfz /config/cloud/dependencies/configuration/f5-cloud-libs-aws.tar.gz -C $libs_dir/f5-cloud-libs/node_modules

    ### BEGIN BASIC ONBOARDING

    # WAIT FOR MCPD (DATABASE) TO BE UP TO BEGIN F5 CONFIG

    . $libs_dir/f5-cloud-libs/scripts/util.sh
    wait_for_bigip

    echo "!!!!! creating admin user"
    tmsh create auth user $${adminUsername} password $${adminPassword} shell bash partition-access replace-all-with { all-partitions { role admin } }
    tmsh save /sys config

    # License / Provision
    echo "!!!!! Initial onboard of BIG-IP"
    f5-rest-node $libs_dir/f5-cloud-libs/scripts/onboard.js \
    -o  /var/log/onboard.log \
    --no-reboot \
    --port $${managementGuiPort} \
    --ssl-port $${managementGuiPort} \
    --host localhost \
    --user $${adminUsername} \
    --password $${adminPassword} \
    --hostname $${hostname} \
    --global-setting hostname:$${hostname} \
    --dns $${dnsServer} \
    --ntp $${ntpServer} \
    --tz $${timezone} \
    --module ltm:nominal

    ###########	BEGIN CUSTOM CONFIG #############
    wait_for_bigip
    # Install DO rpms
    echo "!!!!! Installing DO rpm"
    rpm=${do_rpm}
    DATA="{\"operation\":\"INSTALL\",\"packageFilePath\":\"/config/cloud/dependencies/configuration/$${rpm}\"}"
    response_code=$(/usr/bin/curl -skvvu $${adminUsername}:$${passwd} -w "%%{http_code}" -X POST -H "Content-Type: application/json" -H "Origin: https://$${managementAddress}" "https://localhost:$${managementGuiPort}/mgmt/shared/iapp/package-management-tasks"   --data $${DATA} -o /dev/null)

    if [[ $response_code == 202 ]]; then
      echo "!!!!! Installment of DO rpm succeeded."
    else
      echo "!!!!! Failed to install DO rpm; continuing..."
    fi

    # Install TS rpm
    echo "!!!!! Installing TS rpm"
    rpm=${ts_rpm}
    DATA="{\"operation\":\"INSTALL\",\"packageFilePath\":\"/config/cloud/dependencies/configuration/$${rpm}\"}"
    response_code=$(/usr/bin/curl -skvvu $${adminUsername}:$${passwd} -w "%%{http_code}" -X POST -H "Content-Type: application/json" -H "Origin: https://$${managementAddress}" "https://localhost:$${managementGuiPort}/mgmt/shared/iapp/package-management-tasks"   --data $${DATA} -o /dev/null)

    if [[ $response_code == 202 ]]; then
      echo "!!!!! Installment of TS rpm succeeded."
    else
      echo "!!!!! Failed to deploy TS rpm; continuing..."
    fi

    # Install AS3 rpm
    echo "!!!!! Installing AS3 rpm"
    rpm=${as3_rpm}
    DATA="{\"operation\":\"INSTALL\",\"packageFilePath\":\"/config/cloud/dependencies/configuration/$${rpm}\"}"
    response_code=$(/usr/bin/curl -skvvu $${adminUsername}:$${passwd} -w "%%{http_code}" -X POST -H "Content-Type: application/json" -H "Origin: https://$${managementAddress}" "https://localhost:$${managementGuiPort}/mgmt/shared/iapp/package-management-tasks"   --data $${DATA} -o /dev/null)

    if [[ $response_code == 202 ]]; then
      echo "!!!!! Installment of as3 rpm succeeded."
    else
      echo "!!!!! Failed to deploy as3 rpm; continuing..."
    fi

    # APPLICATION CONFIGURATIONS
    wait_for_bigip

    echo "!!!!! Inital configurations using tmsh"
    tmsh create net tunnels tunnel explicitProxy_tunnel { profile tcp-forward }
    tmsh create net dns-resolver explicitProxy_resolver { forward-zones replace-all-with { . { nameservers replace-all-with { $${dnsResolver}:domain { } } } } route-domain 0 }
    tmsh install sys crypto cert SSL_FORWARD_PROXY.crt from-local-file /config/cloud/dependencies/policy/$${sslCertName}.crt
    tmsh install sys crypto key SSL_FORWARD_PROXY.key from-local-file /config/cloud/dependencies/policy/$${sslCertName}.key
    tmsh create ltm profile client-ssl serverTLS_SSL_FORWARD_PROXY {cert-key-chain replace-all-with { SSL_FWD_ExProxy { cert $${sslCertName}.crt key $${sslCertName}.key  usage CA} default {cert default.crt key default.key } } cert-lookup-by-ipaddr-port disabled defaults-from clientssl mode enabled ssl-forward-proxy enabled }
    tmsh create ltm profile server-ssl clientTLS_SSL_FORWARD_PROXY { defaults-from serverssl ssl-forward-proxy enabled }

    # Below is needed if ever we try and change the managementGuiPort to soemthing other than 8443
    # tmsh modify sys httpd ssl-port $${managementGuiPort}
    # tmsh modify net self-allow defaults add { tcp:$${managementGuiPort} }

    tmsh save /sys config
    echo "!!!!! END configurations using tmsh"
    # Device Onboarding Configs
    echo "!!!!! DO declaration POST"
        #TODO: update file location to use variables
    file_loc="/config/cloud/dependencies/policy/DO_DeclarationExplicitProxy.json"
    response_code=$(/usr/bin/curl -skvvu $${adminUsername}:$${passwd} -w "%%{http_code}" -X POST -H "Content-Type: application/json" -H "Expect:" https://localhost:${managementGuiPort}/mgmt/shared/declarative-onboarding -d @$file_loc -o /dev/null)

    if [[ $response_code == 200 || $response_code == 502 ]]; then
      echo "!!!!! Deployment of DO custom application succeeded."
    else
      echo "!!!!! Failed to deploy DO custom application; continuing..."
    fi

    # Telemetry Streaming Configs
    echo "!!!!! TS declaration POST"
    file_loc="/config/cloud/dependencies/policy/TS_DeclarationExplicitProxy.json"
    response_code=$(/usr/bin/curl -skvvu $${adminUsername}:$${passwd} -w "%%{http_code}" -X POST -H "Content-Type: application/json" -H "Expect:" https://localhost:${managementGuiPort}/mgmt/shared/telemetry/declare -d @$file_loc -o /dev/null)
    if [[ $response_code == 200 || $response_code == 502 ]]; then
      echo "!!!!! Deployment of TS custom application succeeded."
    else
      echo "!!!!! Failed to deploy TS custom application; continuing..."
    fi

    # Application Services 3 Configs
    echo "!!!!! AS3 declaration POST"
    file_loc="/config/cloud/dependencies/policy/as3_DeclarationExplicitProxy.json"
    response_code=$(/usr/bin/curl -skvvu $${adminUsername}:$${passwd} -w "%%{http_code}" -X POST -H "Content-Type: application/json"  -H "Expect:" https://localhost:${managementGuiPort}/mgmt/shared/appsvcs/declare -d @$file_loc -o /dev/null)

    if [[ $response_code == 200 || $response_code == 502 ]]; then
      echo "!!!!! Deployment of AS3 custom application succeeded."
    else
      echo "!!!!! Failed to deploy AS3 custom application; continuing..."
    fi

    echo "!!!!! sleep 15"
    sleep 15
    echo "!!!!! creating log filter to publish audit logs to telemtry HSL"
    tmsh create sys log-config publisher auditlog_hsl2 {destinations replace-all-with {Shared/telemetry_hsl {}}}

    ############ END CUSTOM CONFIG ############

    tmsh save /sys config
    date
    echo "!!!!! FINISHED STARTUP SCRIPT"

runcmd:
  - nohup /config/cloud/startup-script.sh &
