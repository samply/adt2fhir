# ADT2FHIR

Using the two XSLT files ([ADT2MDS_FHIR.xsl](https://github.com/samply/adt2fhir/blob/main/src/main/resources/ADT2MDS_FHIR.xsl) and [MDS2FHIR.xsl](https://github.com/samply/adt2fhir/blob/main/src/main/resources/MDS2FHIR.xsl)), XML files conforming to [ADT/GEKID V2*](https://basisdatensatz.de/xml/) can be transformed into FHIR 
resources conforming to [de.dktk.oncology](https://simplifier.net/packages/de.dktk.oncology/).


## Usage

The main method transforms ADT/GEKID conform data into FHIR bundles.
Therefore, put your ADT/GEKID data in the input directory ```/clincial_data/Input_Patients```. 
Optionally, you can (1) pseudonymize (e.g. see [Mainzelliste](https://bitbucket.org/medicalinformatics/mainzelliste)) and (2) import the data in a FHIR server (e.g. see [Blaze](https://github.com/samply/blaze)).

The tool ADT2FHIR is desinged as docker-compose application.


### Docker

To run ADT2FHIR, put the ADT/GEKID xml files in ```/clinical_data/Input_ADT/``` and run:
```sh
docker-compose up
```

You need at least docker-compose version `1.29.2`.
The configuration is set in the ```docker-compose.yml``` file and is preconfigured as far as possible (you probably won't need to set **#commented** parameters):

###### Environment:

Set the environment variables either directly in Java oder via docker compose (start with the default values from the Dockerfile):


```FILE_PATH``` defines the directory of the clinical ADT/GEKID data in the docker container.
There souldn't be a reason to change this for docker.

```STORE_PATH``` defines the URL of the FHIR server API.
You can use the default value, when using the default BLAZE server (https://github.com/samply/blaze).

```STORE_AUTH``` sets the FHIR server authentication. *Leave it empty if there is no authentication.*

```IDENTIFIER_SYSTEM``` defines the system of the FHIR identifiers.
You can use the default value or set your own system URL.

```MAINZELLISTE_URL``` for pseudonymization in the transformation step; sets the URL of the pseudonymization service. *Leave it empty if there is no pseudonymization.*

```MAINZELLISTE_APIKEY``` sets the pseudonymization service authentication. *Leave it empty if there is no pseudonymization.*

```IDTYPE``` sets the pseudonym type. *Leave it empty if there is no pseudonymization.*

```SALT``` defines a random additional input for the hashing applied in generating the FHIR ids from ADT/GEKID. **Please do change this** 

```SSL_CERTIFICATE_VALIDATION``` can be set to false **IF** your FHIR server is only accessible via https and you do **NOT** have a valid SSL certificate. Not recommended!

```ADD_DEPARTMENTS``` can be set to true if you want to add the departments that commited the patient report (=ADT/GEKID Melder). *Probably not  necessary*.

###### Volumes:

```./clinical_data:/adt2fhir/clinical_data``` You can use the default value, which then mounts the host ```clinical_data``` directory to the docker container.

```/etc/bridgehead/traefik-tls:/.../:ro``` If you use https, please set the correct certificate path here.

###### Network - extra_hosts:
``"host.docker.internal:host-gateway"`` If you run ADT2FHIR in an additional docker-compose file on the same host and you are not managing the docker network yourself, then use this configuration to enable access to other services (FHIR server; pseudonymization service).


## Notes

    Assumes: Patient, Sample, Diagnose always have an Id, other Ids are optional.
    
    -_Lokal_DKTK_ID_Pat_System_ needs to conform to https://www.hl7.org/fhir/datatypes.html#uri

You should modify the identifier system (replace http://dktk.dkfz.de/fhir/onco/core/CodeSystem/PseudonymArtCS with
a local URL). You can just make one up (or use the default), but note that this URL will be used as Identifier.system
in the resulting FHIR Patient resources (Identifer.value will be (A) a **hash** based on patient master data or if pseudonymization 
is configured (B) be replaced by Mainzelliste pseudonym).

Since ids are required in FHIR but optional in the ADT/GEKID XML schema, they are generated via content hashing
if not present. However, it is recommended to provide all optinal ids in the importet ADT/GEKID XML files.
Additionally, ```Patient_ID```, ```Diagnosis_ID``` and ```Sample_ID``` are required. 