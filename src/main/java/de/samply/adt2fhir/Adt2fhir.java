package de.samply.adt2fhir;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.security.KeyManagementException;
import java.security.KeyStoreException;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;
import javax.xml.transform.*;
import javax.xml.transform.stream.StreamResult;
import javax.xml.transform.stream.StreamSource;
import net.sf.saxon.TransformerFactoryImpl;
import net.sf.saxon.s9api.Processor;
import org.apache.http.HttpResponse;
import org.apache.http.NoHttpResponseException;
import org.apache.http.client.config.RequestConfig;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpPost;
import org.apache.http.conn.ssl.NoopHostnameVerifier;
import org.apache.http.conn.ssl.SSLContextBuilder;
import org.apache.http.conn.ssl.TrustAllStrategy;
import org.apache.http.entity.FileEntity;
import org.apache.http.impl.client.CloseableHttpClient;
import org.apache.http.impl.client.HttpClients;
import org.apache.http.util.EntityUtils;


public class Adt2fhir {

    private static final String INPUT_ADT="/InputADT/";
    private static final String ADT_PATIENTS="/ADT_Patients/";
    private static final String FHIR_PATIENTS="/FHIR_Patients/";
    private static final String PROCESSED="/Processed/";

    private static final String ANSI_RESET = "\u001B[0m";
    private static final String ANSI_RED = "\u001B[31m";
    private static final String ANSI_GREEN = "\u001B[32m";
    private static final String DONE = ANSI_GREEN+"...done "+ANSI_RESET;

    public static void main(String[] args) {
        System.out.println("load configuration... ");
        ConfigReader configReader = new ConfigReader();
        try {
            configReader.init();
        } catch (IOException e) {
            System.out.println(" failed");
            e.printStackTrace();
        }
        boolean pseudonymize = false;
        if (!configReader.getMainzelliste_apikey().isEmpty()){
            pseudonymize = checkConnections("Mainzelliste", configReader.getMainzelliste_url(), configReader);
        } else {
            System.out.println("missing Mainzelliste Apikey - Skipping relevant processes");
        }
        boolean FHIRimport = checkConnections("Blaze FHIR Server", configReader.getStore_path()+"?_count=0", configReader);
        System.out.println(DONE);

        System.out.print("initialize transformers... ");
        final TransformerFactoryImpl factory = (TransformerFactoryImpl) TransformerFactory.newInstance("net.sf.saxon.TransformerFactoryImpl", null);
        net.sf.saxon.Configuration saxonConfig = factory.getConfiguration();
        PatientPseudonymizer patientPseudonymizer = new PatientPseudonymizer();
        patientPseudonymizer.initialize(configReader, pseudonymize);
        ((Processor) saxonConfig.getProcessor()).registerExtensionFunction(patientPseudonymizer);
        ((Processor) saxonConfig.getProcessor()).registerExtensionFunction(new UniqueIdGenerator());

        Transformer ADT2singleADTtransformer = null;
        Transformer ADT2MDStransformer = null;
        Transformer MDS2FHIRtransformer = null;
        try {
            ADT2singleADTtransformer = factory.newTransformer(new StreamSource(Adt2fhir.class.getClassLoader().getResourceAsStream("toSinglePatients.xsl")));
            ADT2singleADTtransformer.setParameter("filepath", configReader.getFile_path());
            ADT2MDStransformer = factory.newTransformer(new StreamSource(Adt2fhir.class.getClassLoader().getResourceAsStream("ADT2MDS_FHIR.xsl")));
            MDS2FHIRtransformer = factory.newTransformer(new StreamSource(Adt2fhir.class.getClassLoader().getResourceAsStream("MDS2FHIR.xsl")));
            MDS2FHIRtransformer.setParameter("filepath", configReader.getFile_path());
            MDS2FHIRtransformer.setParameter("identifier_system", configReader.getIdentifier_system());
        } catch (TransformerConfigurationException e) {
            System.out.print("Transformer configuration error");
        }
        System.out.println(DONE);

        long startTime = System.nanoTime();
        System.out.println("Transforming to single Patients... \n");
        processXmlFiles(INPUT_ADT, ADT2singleADTtransformer, configReader);
        long stopTime = System.nanoTime();
        System.out.println(DONE+(stopTime - startTime)/1000000000+ " seconds");


        startTime = System.nanoTime();
        System.out.println("Transforming to FHIR... \n");
        processXmlFiles(ADT_PATIENTS, ADT2MDStransformer, configReader, MDS2FHIRtransformer, true);
        stopTime = System.nanoTime();
        System.out.println(DONE+(stopTime - startTime)/1000000000+ " seconds");

        if (FHIRimport){
            HttpPost httppost = new HttpPost(configReader.getStore_path());
            RequestConfig requestConfig = RequestConfig.copy(RequestConfig.DEFAULT).build();
            httppost.setConfig(requestConfig);
            String encoding = Base64.getEncoder().encodeToString((configReader.getStore_auth()).getBytes());
            httppost.addHeader("content-type", "application/xml+fhir");
            httppost.addHeader("Authorization", "Basic " + encoding);

            startTime = System.nanoTime();
            System.out.println("posting fhir resources to blaze store...\n");
            processXmlFiles(FHIR_PATIENTS, null, configReader, httppost);
            stopTime = System.nanoTime();
            System.out.println(DONE+(stopTime - startTime)/1000000000+ " seconds");
        }
    }


    private static void processXmlFiles (String inputData, Transformer transformer, ConfigReader configReader){
        processXmlFiles (inputData, transformer, configReader, null, false, null);
    }

    private static void processXmlFiles (String inputData, Transformer transformer, ConfigReader configReader, Transformer transformer2, Boolean transformWrittenResults){
        processXmlFiles (inputData, transformer, configReader, transformer2, transformWrittenResults, null);
    }

    private static void processXmlFiles (String inputData, Transformer transformer, ConfigReader configReader, HttpPost httppost){
        processXmlFiles (inputData, transformer, configReader, null, false, httppost);
    }
    private static void processXmlFiles (String inputData, Transformer transformer, ConfigReader configReader, Transformer transformer2, Boolean transformWrittenResults, HttpPost httppost ){
        //System.out.print("load "+ filetype + " files...");
        File fileDir = new File(configReader.getFile_path() + inputData);
        File[] listOfFiles = fileDir.listFiles();
        if (listOfFiles==null){
            System.out.println("ABORTING: empty "+ fileDir +" dir");
        }
        else {
            int counter=0;
            for (File inputFile : listOfFiles) {
                //System.out.println(inputFile);
                if (inputFile.isFile() & inputFile.getName().toLowerCase().endsWith(".xml")) {
                    counter+=1;
                    System.out.println("\u001B[AFile " + counter + " of " + (listOfFiles.length) + " / Filename: " + inputFile);
                    if (transformer ==null){
                        try {
                            postToFhirStore(inputFile, httppost, configReader);
                        } catch (IOException e) {
                            counter-=1;
                            System.out.print("ERROR - FHIR import: problem with file " + inputFile);
                            e.printStackTrace();
                        }
                    }
                    else {
                        //System.out.print("processing file " + inputFile.getName() + "...");
                        String inputFileString = null;
                        try {
                            inputFileString = Files.readString(Paths.get(String.valueOf(inputFile)));
                        } catch (IOException e) {
                            counter-=1;
                            System.out.print("ERROR - reading: problem with file " + inputFile);
                            e.printStackTrace();
                        }
                        try {
                            transformer.setParameter("customPrefix", counter);
                            String xmlResult = applyXslt(inputFileString, transformer);
                            if(transformWrittenResults){
                                transformer2.setParameter("customPrefix", inputFile.getName());
                                applyXslt(xmlResult, transformer2);
                                inputFile.deleteOnExit();
                            }
                            else {
                                inputFile.renameTo(new File(configReader.getFile_path() + PROCESSED + inputFile.getName()));
                            }
                        } catch (UnsupportedEncodingException | TransformerException | RuntimeException e) {
                            counter-=1;
                            System.out.print("ERROR - transformation: problem with file " + inputFile);
                            //e.printStackTrace();
                        }
                    }
                }
                else if (inputFile.isFile() & inputFile.getName().toLowerCase().endsWith(".gitignore")) {
                    //do nothing
                }
                else {
                    System.out.print("\n\t\u001B[31m" + "skipping file:" + "\u001B[0m" + " '" + inputFile.getName() + "' - not a valid xml file");
                }
            }
        }
    }

    private static void postToFhirStore(File inputFile, HttpPost httppost, ConfigReader configReader) throws IOException {
        CloseableHttpClient httpclient = null;
        try {
            httpclient = getHttpClient(configReader.getSsl_certificate_validation());
        } catch (NoSuchAlgorithmException | KeyStoreException | KeyManagementException e) {
            throw new RuntimeException(e);
        }
        File file = new File(inputFile.toString());
        FileEntity entity = new FileEntity(file);
        httppost.setEntity(entity);
        HttpResponse response = httpclient.execute(httppost);
        if (!response.getStatusLine().getReasonPhrase().equals("OK")) {
            System.out.println("Error - FHIR import: could not import file"+ inputFile.getName());
            System.out.println(EntityUtils.toString(response.getEntity(), StandardCharsets.UTF_8));
        }
        else {
            inputFile.deleteOnExit();
        }
        httpclient.close();
    }


    private static String applyXslt(String xmlString, Transformer transformer) throws UnsupportedEncodingException, TransformerException {
        Source xmlSource = new StreamSource(new ByteArrayInputStream(xmlString.getBytes(StandardCharsets.UTF_8.name())));
        Writer outputWriter = new StringWriter();
        StreamResult transformed = new StreamResult(outputWriter);
        transformer.transform(xmlSource, transformed);
        return outputWriter.toString();
    }

    private static CloseableHttpClient getHttpClient(Boolean secure) throws NoSuchAlgorithmException, KeyStoreException, KeyManagementException {
        CloseableHttpClient httpclient = null;
        if (!secure){
            httpclient = HttpClients.custom()
                    .setSSLContext(new SSLContextBuilder().loadTrustMaterial(null, TrustAllStrategy.INSTANCE).build())
                    .setSSLHostnameVerifier(NoopHostnameVerifier.INSTANCE).build();
        }
        else {
            httpclient = HttpClients.createDefault();
        }
        return httpclient;
    }

    private static boolean checkConnections(String servicename, String URL, ConfigReader configReader) {
        boolean serviceAvailable = false;
        CloseableHttpClient httpclient = null;
        try {
            httpclient = getHttpClient(configReader.getSsl_certificate_validation());
        } catch (NoSuchAlgorithmException | KeyStoreException | KeyManagementException e) {
            throw new RuntimeException(e);
        }
        HttpResponse httpResponse;
        HttpGet httpGetRequest;
        if (URL != null && !URL.isEmpty()) {
            httpGetRequest = new HttpGet(URL);
            String encoding = Base64.getEncoder().encodeToString((configReader.getStore_auth()).getBytes());
            httpGetRequest.addHeader("Authorization", "Basic " + encoding);
            try {
                httpResponse = httpclient.execute(httpGetRequest);
                if (httpResponse.getStatusLine().getReasonPhrase().equals("OK") || httpResponse.getStatusLine().getStatusCode()==200) {
                    System.out.println(servicename + " is accessible: " + URL);
                    serviceAvailable = true;
                }
                else {
                    System.out.println(servicename + " is NOT accessible: " + URL + httpResponse.getStatusLine());
                }
                httpclient.close();
            } catch (NoHttpResponseException e){
                System.out.println("Error: NoHttpResponseException while trying to access " + servicename + " at " + URL + " - Skipping relevant processes");
            } catch (IOException e) {
                System.out.println("Error: RuntimeException while trying to access " + servicename + " at " + URL + " - Skipping relevant processes");
            }
        }
        else {
            System.out.println(servicename + " url not specified. Skipping relevant processes");
        }
        return serviceAvailable;
    }
}
