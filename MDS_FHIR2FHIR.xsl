<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<xsl:stylesheet xmlns="http://hl7.org/fhir" xmlns:mds2fhir="https://github.com/samply/adt2fhir/blob/main/MDS_FHIR2FHIR" xmlns:dktk="http://dktk.dkfz.de" xmlns:saxon="http://saxon.sf.net" xmlns:xalan="http://xml.apache.org/xalan" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" exclude-result-prefixes="xs xsi dktk saxon xalan mds2fhir #default" version="2.0" xpath-default-namespace="http://www.mds.de/namespace">

    <!-- Settings-->
    <!-- System für lokale Identifier-->
    <xsl:variable name="Lokal_DKTK_ID_Pat_System">http://fhir.example.org/LokaleTumorPatientenIds</xsl:variable>

    <!-- Ende Settings -->

    <xsl:output encoding="UTF-8" indent="yes" method="xml" />
    <xsl:output omit-xml-declaration="yes" indent="yes" />
    <xsl:strip-space elements="*" />

    <xsl:template match="/">

        <xsl:param name="Patient_ID" select="Patienten/@Patient_ID" />

        <xsl:variable name="root" select="/" />
        <xsl:apply-templates select="Patienten/Patient" mode="patient" />

    </xsl:template>

    <xsl:template match="Patient" mode="patient">
        <xsl:variable name="Patient_ID" select="@Patient_ID" />
        <xsl:result-document href="./Bundle_{$Patient_ID}.xml">
        <Bundle xmlns="http://hl7.org/fhir">
            <id value="{generate-id()}" />
            <type value="transaction" />
            <entry>
                <fullUrl value="http://example.com/Patient/{$Patient_ID}" />
                <resource>
                    <Patient>
                        <id value="{$Patient_ID}" />
                        <meta>
                            <profile value="https://fhir.bbmri.de/StructureDefinition/Patient" />
                        </meta>
                        <identifier>
                            <system value="{$Lokal_DKTK_ID_Pat_System}"/>
                            <value value="{./DKTK_LOCAL_ID}"/>
                        </identifier>
                        <xsl:if test="./Verlauf/Tod">
                        <decasedDateTime value="{mds2fhir:transformDate(./Verlauf/Tod/Sterbedatum)}"/>
                        </xsl:if>
                        <gender>
                            <xsl:choose>
                                <xsl:when test="./Geschlecht='M'">
                                    <xsl:attribute name="value">male</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Geschlecht='F'">
                                    <xsl:attribute name="value">female</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Geschlecht='S'">
                                    <xsl:attribute name="value">other</xsl:attribute>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:attribute name="value">unknown</xsl:attribute>
                                </xsl:otherwise>
                            </xsl:choose>
                        </gender>
                        <birthDate value="{mds2fhir:transformDate(./Geburtsdatum)}" />
                    </Patient>
                </resource>
                <request>
                    <method value="PUT" />
                    <url value="Patient/{$Patient_ID}" />
                </request>
            </entry>
            <entry>
                <fullUrl value="http://example.com/Observation/{$Patient_ID}-vitalstatus" />
                <resource>
                    <Observation>
                        <id value="{$Patient_ID}-vitalstatus" />
                        <meta>
                            <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-Vitalstatus" />
                        </meta>
                        <status value="registered" />
                        <code>
                            <coding>
                                <system value="http://loinc.org" />
                                <code value="75186-7" />
                            </coding>
                        </code>
                        <subject>
                            <reference value="Patient/{$Patient_ID}" />
                        </subject>
                        <effectiveDateTime value="{mds2fhir:transformDate(./Datum_des_letztbekannten_Vitalstatus)}" />
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/VitalstatusCS" />
                                <code value="{./Vitalstatus}" />
                            </coding>
                        </valueCodeableConcept>
                    </Observation>
                </resource>
                <request>
                    <method value="PUT" />
                    <url value="Observation/{$Patient_ID}-vitalstatus" />
                </request>
            </entry>

            <!-- Patienten > Patient > Sample -->
            <xsl:apply-templates select="./Sample" mode="sample">
                <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            </xsl:apply-templates>

            <!-- Patienten > Patient > Diagnose -->
            <xsl:apply-templates select="./Diagnosis" mode="diagnosis">
                <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            </xsl:apply-templates>

        </Bundle>
    </xsl:result-document>
    </xsl:template>

    <xsl:template match="Sample" mode="sample">
        <xsl:param name="Patient_ID" select="../@Patient_ID" />
        <xsl:variable name="Sample_ID" select="@Sample_ID" />
        <entry>
            <fullUrl value="http://example.com/Specimen/{$Sample_ID}"/>
            <resource>
              <Specimen>
                <id value="{$Sample_ID}"/>
                <meta>
                  <profile value="https://fhir.bbmri.de/StructureDefinition/Specimen"/>
                </meta>
                <type>
                  <coding>
                    <system value="https://fhir.bbmri.de/CodeSystem/SampleMaterialType"/>
                    <code>
                        <xsl:choose>
                            <xsl:when test="./Probentyp='Gewebeprobe'">
                            <xsl:choose>
                                <xsl:when test="./Fixierungsart='Kryo/Frisch (FF)'">
                                <xsl:choose>
                                    <xsl:when test="./Probenart='Tumorgewebe'">
                                        <xsl:attribute name="value">tumor-tissue-frozen</xsl:attribute>
                                    </xsl:when>
                                    <xsl:when test="./Probenart='Normalgewebe'">
                                        <xsl:attribute name="value">normal-tissue-frozen</xsl:attribute>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:attribute name="value">other-tissue-frozen</xsl:attribute>
                                    </xsl:otherwise>
                                </xsl:choose>
                                </xsl:when>
                                <xsl:when test="./Fixierungsart='Paraffin (FFPE)'">
                                <xsl:choose>
                                    <xsl:when test="./Probenart='Tumorgewebe'">
                                        <xsl:attribute name="value">tumor-tissue-ffpe</xsl:attribute>
                                    </xsl:when>
                                    <xsl:when test="./Probenart='Normalgewebe'">
                                        <xsl:attribute name="value">normal-tissue-ffpe</xsl:attribute>
                                    </xsl:when>
                                    <xsl:otherwise>
                                        <xsl:attribute name="value">other-tissue-ffpe</xsl:attribute>
                                    </xsl:otherwise>
                                </xsl:choose>
                                </xsl:when>
                            </xsl:choose>
                            </xsl:when>
                            <xsl:when test="./Probentyp='Flüssigprobe'">
                            <xsl:choose>
                                <xsl:when test="./Probenart='Vollblut'">
                                    <xsl:attribute name="value">whole-blood</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Probenart='Serum'">
                                    <xsl:attribute name="value">blood-serum</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Probenart='Plasma'">
                                    <xsl:attribute name="value">blood-plasma</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Probenart='Urin'">
                                    <xsl:attribute name="value">urine</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Probenart='Liquor'">
                                    <xsl:attribute name="value">csf-liquor</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Probenart='Knochenmark'">
                                    <xsl:attribute name="value">bone-marrow</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Probenart='DNA'">
                                <xsl:attribute name="value">dna</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Probenart='RNA'">
                                    <xsl:attribute name="value">rna</xsl:attribute>
                                </xsl:when>
                                <xsl:when test="./Probenart='Protein'">
                                    <xsl:attribute name="value">derivative-other</xsl:attribute>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:attribute name="value">liquid-other</xsl:attribute>
                                </xsl:otherwise>
                            </xsl:choose>
                            </xsl:when>
                        </xsl:choose>
                    </code>
                  </coding>
                </type>
                <subject>
                  <reference value="Patient/{$Patient_ID}"/>
                </subject>
                <collection>
                  <collectedDateTime value="{mds2fhir:transformDate(./Entnahmedatum)}"/>
                </collection>
              </Specimen>
            </resource>
            <request>
              <method value="PUT"/>
              <url value="Specimen/{$Sample_ID}"/>
            </request>
          </entry>
    </xsl:template>
    <xsl:template match="Diagnosis" mode="diagnosis">
        <xsl:param name="Patient_ID" select="../@Patient_ID" />
        <xsl:variable name="Diagnosis_ID" select="./@Diagnosis_ID" />

        <entry>
            <fullUrl value="http://example.com/Condition/{$Diagnosis_ID}" />
            <resource>
                <Condition xmlns="http://hl7.org/fhir">
                    <id value="{$Diagnosis_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Condition-Primaerdiagnose" />
                    </meta>
                    <xsl:for-each select="./Tumor/Metastasis">
                        <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-Fernmetastasen">
                            <valueReference>
                                <reference value="Observation/{mds2fhir:getID(./@Metastasis_ID, '', generate-id())}" />
                            </valueReference>
                        </extension>
                    </xsl:for-each>
                    <code>
                        <coding>
                            <system value="{mds2fhir:getICDType(./ICD-Katalog_Version)}" />
                            <version value="{mds2fhir:getVersionYear(./ICD-Katalog_Version)}" />
                            <code value="{./Diagnose}" />
                        </coding>
                    </code>
                    <bodySite>
                        <coding>
                            <system value="urn:oid:2.16.840.1.113883.6.43.1" />
                            <version value="{./Tumor/ICD-O_Katalog_Topographie_Version}" />
                            <code value="{./Tumor/Lokalisation}" />
                        </coding>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SeitenlokalisationCS" />
                            <code value="{./Tumor/Seitenlokalisation}" />
                        </coding>
                    </bodySite>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <onsetAge>
                        <value value="{./Alter_bei_Erstdiagnose}" />
                        <unit value="Jahre" />
                        <system value="http://unitsofmeasure.org" />
                        <code value="a" />
                    </onsetAge>
                    <recordedDate value="{mds2fhir:transformDate(./Tumor_Diagnosedatum)}" />
                    <xsl:for-each select="./Tumor/TNM">
                    <stage>
                        <assessment>
                            <reference value="Observation/{mds2fhir:getID(./@TNM_ID, mds2fhir:transformDate(./Datum_der_TNM-Dokumentation-Datum_Befund), generate-id())}" />
                        </assessment>
                    </stage>
                    </xsl:for-each>
                    <evidence>
                        <xsl:for-each select="./Tumor/Histology">
                            <detail>
                                <reference value="Observation/{mds2fhir:getID(./@Histology_ID,'',generate-id())}" />
                            </detail>
                    </xsl:for-each>
                    </evidence>
                </Condition>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Condition/{$Diagnosis_ID}" />
            </request>
        </entry>

        <xsl:apply-templates select="./Tumor" mode="tumor">
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID" />
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
        </xsl:apply-templates>
    </xsl:template>


    <xsl:template match="SYST">
        <xsl:param name="Progress_ID" />
        <xsl:param name="Patient_ID" />
        <xsl:param name="Diagnosis_ID" />
        <xsl:variable name="System_Therapy_ID" select="mds2fhir:getID(./@SYST_ID, mds2fhir:transformDate(./Systemische_Therapie_Beginn), generate-id())" as="xs:string" />
        <entry>
            <fullUrl value="http://example.com/MedicationStatement/{$System_Therapy_ID}" />
            <resource>
                <MedicationStatement>
                    <id value="{$System_Therapy_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-MedicationStatement-Systemtherapie" />
                    </meta>
                    <xsl:if test="./Systemische_Therapie_Stellung_zu_operativer_Therapie">
                        <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-StellungZurOp">
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTStellungOPCS" />
                                    <code value="{./Systemische_Therapie_Stellung_zu_operativer_Therapie}" />
                                </coding>
                            </valueCodeableConcept>
                        </extension>
                    </xsl:if>
                    <xsl:if test="./Intention_Chemotherapie">
                        <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-SYSTIntention">
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTIntentionCS" />
                                    <code value="{./Intention_Chemotherapie}" />
                                </coding>
                            </valueCodeableConcept>
                        </extension>
                    </xsl:if>
                    <xsl:if test="./Lokale_Beurteilung_Resttumor">
                        <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-LokaleResidualstatus">
                            <reference value="Observation/{mds2fhir:getID('','', generate-id(./Lokale_Beurteilung_Resttumor))}" />
                        </extension>
                    </xsl:if>
                    <xsl:if test="./Gesamtbeurteilung_Resttumor">
                        <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-GesamtbeurteilungResidualstatus">
                            <reference value="Observation/{mds2fhir:getID('','', generate-id(./Gesamtbeurteilung_Resttumor))}" />
                        </extension>
                    </xsl:if>
                    <xsl:choose>
                        <xsl:when test="./Systemische_Therapie_Ende">
                            <xsl:choose>
                                <xsl:when test="SYST_Ende_Grund='E' or SYST_Ende_Grund='R'">
                                    <status value="completed" />
                                </xsl:when>
                                <xsl:when test="SYST_Ende_Grund='U'">
                                    <status value="unknown" />
                                </xsl:when>
                                <xsl:otherwise>
                                    <status value="stopped" />
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:choose>
                                <xsl:when test="./Systemische_Therapie_Beginn">
                                    <status value="active" />
                                </xsl:when>
                                <xsl:otherwise>
                                    <status value="intended" />
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:otherwise>
                    </xsl:choose>
                    <category>
                        <xsl:for-each select="./SYST_Therapieart">
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTTherapieartCS" />
                                <code value="{.}" />
                            </coding>
                        </xsl:for-each>
                    </category>
                    <!-- There may be more substances, but we can only save one here -->
                    <medicationCodeableConcept>
                    <xsl:choose>
                        <xsl:when test="./SYST_Substanz">
                        <text value="{./SYST_Substanz}" />
                    </xsl:when>
                        <xsl:otherwise>
                            <text value="Keine Angabe zur Substanz" />
                        </xsl:otherwise>
                    </xsl:choose>
                    </medicationCodeableConcept>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <xsl:if test="./Systemische_Therapie_Beginn or ./Systemische_Therapie_Ende">
                        <effectivePeriod>
                            <xsl:if test="./Systemische_Therapie_Beginn">
                                <start value="{mds2fhir:transformDate(./Systemische_Therapie_Beginn)}" />
                            </xsl:if>
                            <xsl:if test="./Systemische_Therapie_Ende">
                                <end value="{mds2fhir:transformDate(./Systemische_Therapie_Ende)}" />
                            </xsl:if>
                        </effectivePeriod>
                    </xsl:if>
                    <reasonReference>
                        <reference value="Condition/{$Diagnosis_ID}" />
                    </reasonReference> 
                </MedicationStatement>
            </resource>
            <request>
                <method value="PUT" />
                <url value="MedicationStatement/{$System_Therapy_ID}" />
            </request>
        </entry>

        <xsl:for-each select="./SYST_Nebenwirkung">
            <xsl:variable name="Nebenwirkung_ID" select="mds2fhir:getID('', '', generate-id())" as="xs:string" />
            <entry>
                <fullUrl value="http://example.com/AdverseEvent/{$Nebenwirkung_ID}" />
                <resource>
                    <AdverseEvent xmlns="http://hl7.org/fhir">
                        <id value="{$Nebenwirkung_ID}" />
                        <actuality value="actual" />
                        <event>
                            <text value="{./Nebenwirkung_Art}" />
                        </event>
                        <subject>
                            <reference value="Patient/{$Patient_ID}" />
                        </subject>
                        <suspectEntity>
                            <instance>
                                <reference value="MedicationStatement/{$System_Therapy_ID}" />
                            </instance>
                        </suspectEntity>
                    </AdverseEvent>
                </resource>
                <request>
                    <method value="PUT" />
                    <url value="AdverseEvent/{$Nebenwirkung_ID}" />
                </request>
            </entry>
        </xsl:for-each>

        <xsl:if test="./Gesamtbeurteilung_Resttumor">
        <entry>
            <fullUrl value="http://example.com/Observation/{mds2fhir:getID('','', generate-id(./Gesamtbeurteilung_Resttumor))}" />
            <resource>
                <Observation xmlns="http://hl7.org/fhir">
                    <id value="{mds2fhir:getID('','', generate-id(./Gesamtbeurteilung_Resttumor))}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-GesamtbeurteilungResidualstatus" />
                    </meta>
                    <status value="final" />
                    <code>
                        <coding>
                            <system value="http://loinc.org" />
                            <code value="81169-5" />
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <valueCodeableConcept>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/GesamtbeurteilungResidualstatusCS" />
                            <code value="{./Gesamtbeurteilung_Resttumor}" />
                        </coding>
                    </valueCodeableConcept>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{mds2fhir:getID('','', generate-id(./Gesamtbeurteilung_Resttumor))}" />
            </request>
        </entry>
    </xsl:if>
    <xsl:if test="./Lokale_Beurteilung_Resttumor">
        <entry>
            <fullUrl value="http://example.com/Observation/{mds2fhir:getID('','', generate-id(./Lokale_Beurteilung_Resttumor))}" />
            <resource>
                <Observation xmlns="http://hl7.org/fhir">
                    <id value="{mds2fhir:getID('','', generate-id(./Lokale_Beurteilung_Resttumor))}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-LokaleBeurteilungResidualstatus" />
                    </meta>
                    <status value="final" />
                    <code>
                        <coding>
                            <system value="http://loinc.org" />
                            <code value="84892-9" />
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <valueCodeableConcept>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/LokaleBeurteilungResidualstatusCS" />
                            <code value="{./Lokale_Beurteilung_Resttumor}" />
                        </coding>
                    </valueCodeableConcept>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{mds2fhir:getID('','', generate-id(./Lokale_Beurteilung_Resttumor))}" />
            </request>
        </entry>
    </xsl:if>


    </xsl:template>

    <xsl:template match="ST">
        <xsl:param name="Progress_ID" />
        <xsl:param name="Patient_ID" />
        <xsl:param name="Diagnosis_ID" />
        <xsl:variable name="Radiation_Therapy_ID" select="mds2fhir:getID(./@ST_ID,'', generate-id())" as="xs:string" />
        <entry>
            <fullUrl value="http://example.com/Procedure/{$Radiation_Therapy_ID}" />
            <resource>
                <Procedure>
                    <id value="{$Radiation_Therapy_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Procedure-Strahlentherapie" />
                    </meta>
                    <xsl:if test="./Strahlentherapie_Stellung_zu_operativer_Therapie">
                        <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-StellungZurOp">
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTStellungOPCS" />
                                    <code value="{./Strahlentherapie_Stellung_zu_operativer_Therapie}" />
                                </coding>
                            </valueCodeableConcept>
                        </extension>
                    </xsl:if>
                    <xsl:if test="./Intention_Strahlentherapie">
                        <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-SYSTIntention">
                            <valueCodeableConcept>
                                <coding>
                                    <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTIntentionCS" />
                                    <code value="{./Intention_Strahlentherapie}" />
                                </coding>
                            </valueCodeableConcept>
                        </extension>
                    </xsl:if>
                    <status value="unknown" />
                    <category>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTTherapieartCS" />
                            <code value="ST" />
                            <display value="Strahlentherapie" />
                        </coding>
                    </category>
                    <code>
                        <coding>
                            <system value="http://fhir.de/CodeSystem/dimdi/ops"/>
                            <code value="8-52"/>
                            <display value="Strahlentherapie"/>
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <reasonReference>
                        <reference value="Condition/{$Diagnosis_ID}" />
                    </reasonReference> 
                    <xsl:if test="./Lokale_Beurteilung_Resttumor or ./Gesamtbeurteilung_Resttumor">
                    <outcome>
                        <xsl:if test="./Lokale_Beurteilung_Resttumor">
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/LokaleBeurteilungResidualstatusCS" />
                            <code value="{./Lokale_Beurteilung_Resttumor}" />
                        </coding>
                    </xsl:if>
                    <xsl:if test="./Gesamtbeurteilung_Resttumor">
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/GesamtbeurteilungResidualstatusCS" />
                            <code value="{./Gesamtbeurteilung_Resttumor}" />
                        </coding>
                    </xsl:if>
                    </outcome>
                </xsl:if>
                <xsl:for-each select="./ST_Nebenwirkung">
                    <complication>
                        <text value="./Nebenwirkung_Art"/>
                    </complication>
                </xsl:for-each>
                </Procedure>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Procedure/{$Radiation_Therapy_ID}" />
            </request>
        </entry>

        <xsl:for-each select="./Bestrahlung">
        <xsl:variable name="Single_Radiation_Therapy_ID" select="mds2fhir:getID('',mds2fhir:transformDate(./ST_Beginn_Datum), generate-id())" as="xs:string" />
        <entry>
            <fullUrl value="http://example.com/Procedure/{$Single_Radiation_Therapy_ID}" />
            <resource>
                <Procedure>
                    <id value="{$Single_Radiation_Therapy_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Procedure-Strahlentherapie" />
                    </meta>
                    <partOf>
                        <reference value="Procedure/{$Radiation_Therapy_ID}"/>
                    </partOf>
                    <xsl:choose>
                        <xsl:when test="./ST_Ende_Datum">
                            <xsl:choose>
                                <xsl:when test="ST_Ende_Grund='E'">
                                    <status value="completed" />
                                </xsl:when>
                                <xsl:when test="ST_Ende_Grund='U'">
                                    <status value="unknown" />
                                </xsl:when>
                                <xsl:otherwise>
                                    <status value="stopped" />
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:choose>
                                <xsl:when test="./ST_Beginn_Datum">
                                    <status value="in-progress" />
                                </xsl:when>
                                <xsl:otherwise>
                                    <status value="preparation" />
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:otherwise>
                    </xsl:choose>
                    <category>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTTherapieartCS" />
                            <code value="ST" />
                            <display value="Strahlentherapie" />
                        </coding>
                    </category>
                    <code>
                        <coding>
                            <system value="http://fhir.de/CodeSystem/dimdi/ops"/>
                            <code value="8-52"/>
                            <display value="Strahlentherapie"/>
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <xsl:if test="./ST_Beginn_Datum or ./ST_Ende_Datum">
                        <performedPeriod>
                            <xsl:if test="./ST_Beginn_Datum">
                                <start value="{mds2fhir:transformDate(./ST_Beginn_Datum)}" />
                            </xsl:if>
                            <xsl:if test="./ST_Ende_Datum">
                                <end value="{mds2fhir:transformDate(./ST_Ende_Datum)}" />
                            </xsl:if>
                        </performedPeriod>
                    </xsl:if>
                    <reasonReference>
                        <reference  value="Condition/{$Diagnosis_ID}" />
                    </reasonReference>
                </Procedure>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Procedure/{$Single_Radiation_Therapy_ID}" />
            </request>
        </entry>
    </xsl:for-each>

    </xsl:template>

    <xsl:template match="OP">
        <xsl:param name="Patient_ID" />
        <xsl:param name="Diagnosis_ID" />

        <xsl:variable name="OP_ID" select="mds2fhir:getID(./@OP_ID, '', generate-id())" as="xs:string" />
        
        <entry>
            <fullUrl value="http://example.com/Procedure/{$OP_ID}" />
            <resource>
                <Procedure>
                    <id value="{$OP_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Procedure-Operation" />
                    </meta>
                    <xsl:if test="./Intention_OP">
                    <extension url="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Extension-OPIntention">
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/OPIntentionCS" />
                                <code value="{./Intention_OP}" />
                            </coding>
                        </valueCodeableConcept>
                    </extension>
                </xsl:if>
                    <status value="completed" />
                    <category>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/SYSTTherapieartCS" />
                            <code value="OP" />
                            <display value="Operation" />
                        </coding>
                    </category>
                    <code>
                        <xsl:for-each select="./OP_OPS">
                            <coding>
                                <system value="http://fhir.de/CodeSystem/dimdi/ops" />
                                <xsl:if test="../../OP_OPS_Version">
                                <version value="{../../OP_OPS_Version}"/>
                            </xsl:if>
                                <code value="{.}" />
                            </coding>
                        </xsl:for-each>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <reasonReference>
                        <reference value="Condition/{$Diagnosis_ID}" />
                    </reasonReference>
                    <outcome>
                        <xsl:if test="./Lokale_Beurteilung_Resttumor">
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/LokaleBeurteilungResidualstatusCS" />
                            <code value="{./Lokale_Beurteilung_Resttumor}" />
                        </coding>
                    </xsl:if>
                    <xsl:if test="./Gesamtbeurteilung_Resttumor">
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/GesamtbeurteilungResidualstatusCS" />
                            <code value="{./Gesamtbeurteilung_Resttumor}" />
                        </coding>
                    </xsl:if>
                    </outcome>
                </Procedure>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Procedure/{$OP_ID}" />
            </request>
        </entry>

        <xsl:apply-templates select="./Histology">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
        </xsl:apply-templates>

        <xsl:apply-templates select="./TNM">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
        </xsl:apply-templates>

    </xsl:template>

    <xsl:template match="Verlauf">
        <xsl:param name="Tumor_ID" />
        <xsl:param name="Patient_ID" />
        <xsl:param name="Diagnosis_ID" />
        <xsl:variable name="Progress_ID" select="mds2fhir:getID(./@Progress_ID, '', generate-id())" as="xs:string" />
        <xsl:variable name="Lym_Rezidiv_ID" select="mds2fhir:getID('', '', generate-id(./Lymphknoten-Rezidiv))" as="xs:string"/>
        <xsl:variable name="Fernmetastasen_ID" select="mds2fhir:getID('', '', generate-id(./Fernmetastasen))" as="xs:string"/>
        <xsl:variable name="Lokales_Rezidiv_ID" select="mds2fhir:getID('', '', generate-id(./Lokales-regionäres_Rezidiv))" as="xs:string"/>
        <xsl:variable name="Ansprechen_ID" select="mds2fhir:getID('', '', generate-id(./Ansprechen_im_Verlauf))" as="xs:string"/>

        <entry>
            <fullUrl value="http://example.com/ClinicalImpression/{$Progress_ID}" />
            <resource>
                <ClinicalImpression xmlns="http://hl7.org/fhir">
                    <id value="{$Progress_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-ClinicalImpression-Verlauf" />
                    </meta>
                    <status value="completed" />
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <effectiveDateTime value="{mds2fhir:transformDate(./Datum_Verlauf)}" />
                    <problem>
                        <reference value="Condition/{$Diagnosis_ID}" />
                    </problem>
                    <xsl:for-each select="./TNM">
                    <finding>
                        <itemReference>
                            <reference value="Observation/{mds2fhir:getID(./@TNM_ID, mds2fhir:transformDate(./Datum_der_TNM-Dokumentation-Datum_Befund), generate-id())}" />
                        </itemReference>
                    </finding>
                </xsl:for-each>
                <xsl:for-each select="./Histology">
                    <finding>
                        <itemReference>
                            <reference value="Observation/{mds2fhir:getID(./@Histology_ID, mds2fhir:transformDate(./Tumor_Histologiedatum), generate-id())}" />
                        </itemReference>
                    </finding>
                </xsl:for-each>
                <xsl:for-each select="./Metastasis">
                    <finding>
                        <itemReference>
                            <reference value="Observation/{mds2fhir:getID('', '', generate-id())}" />
                        </itemReference>
                    </finding>
                </xsl:for-each>
                <finding>
                <itemReference>
                    <reference value="Observation/{$Lokales_Rezidiv_ID}" />
                </itemReference>
            </finding>
            <finding>
                <itemReference>
                    <reference value="Observation/{$Lym_Rezidiv_ID}" />
                </itemReference>
            </finding>
            <finding>
                <itemReference>
                    <reference value="Observation/{$Fernmetastasen_ID}" />
                </itemReference>
            </finding>
            <finding>
                <itemReference>
                    <reference value="Observation/{$Ansprechen_ID}" />
                </itemReference>
            </finding>
                </ClinicalImpression>
            </resource>
            <request>
                <method value="PUT" />
                <url value="ClinicalImpression/{$Progress_ID}" />
            </request>
        </entry>
        <entry>
            <fullUrl value="http://example.com/Observation/{$Lokales_Rezidiv_ID}" />
            <resource>
                <Observation xmlns="http://hl7.org/fhir">
                    <id value="{$Lokales_Rezidiv_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-LokalerTumorstatus" />
                    </meta>
                    <status value="final" />
                    <code>
                        <coding>
                            <system value="http://loinc.org" />
                            <code value="LA4583-6" />
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <effectiveDateTime value="{mds2fhir:transformDate(./Datum_Verlauf)}" />
                    <valueCodeableConcept>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/VerlaufLokalerTumorstatusCS" />
                            <code value="{./Lokales-regionäres_Rezidiv}" />
                        </coding>
                    </valueCodeableConcept>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{$Lokales_Rezidiv_ID}" />
            </request>
        </entry>
        <entry>
            <fullUrl value="http://example.com/Observation/{$Lym_Rezidiv_ID}" />
            <resource>
                <Observation xmlns="http://hl7.org/fhir">
                    <id value="{$Lym_Rezidiv_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-TumorstatusLymphknoten" />
                    </meta>
                    <status value="final" />
                    <code>
                        <coding>
                            <system value="http://loinc.org" />
                            <code value="LA4370-8" />
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <effectiveDateTime value="{mds2fhir:transformDate(./Datum_Verlauf)}" />
                    <valueCodeableConcept>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/VerlaufTumorstatusLymphknotenCS" />
                            <code value="{./Lymphknoten-Rezidiv}" />
                        </coding>
                    </valueCodeableConcept>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{$Lym_Rezidiv_ID}" />
            </request>
        </entry>
        <entry>
            <fullUrl value="http://example.com/Observation/{$Fernmetastasen_ID}" />
            <resource>
                <Observation xmlns="http://hl7.org/fhir">
                    <id value="{$Fernmetastasen_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-TumorstatusFernmetastasen" />
                    </meta>
                    <status value="final" />
                    <code>
                        <coding>
                            <system value="http://loinc.org" />
                            <code value="LA4226-2" />
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <effectiveDateTime value="{mds2fhir:transformDate(./Datum_Verlauf)}" />
                    <valueCodeableConcept>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/VerlaufTumorstatusFernmetastasenCS" />
                                    <code value="{./Fernmetastasen}" />
                        </coding>
                    </valueCodeableConcept>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{$Fernmetastasen_ID}" />
            </request>
        </entry>
        <entry>
            <fullUrl value="http://example.com/Observation/{$Ansprechen_ID}" />
            <resource>
                <Observation xmlns="http://hl7.org/fhir">
                    <id value="{$Ansprechen_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-GesamtbeurteilungTumorstatus" />
                    </meta>
                    <status value="final" />
                    <code>
                        <coding>
                            <system value="http://loinc.org" />
                            <code value="21976-6" />
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <effectiveDateTime value="{mds2fhir:transformDate(./Datum_Verlauf)}" />
                    <valueCodeableConcept>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/GesamtbeurteilungTumorstatusCS" />
                            <code value="{./Ansprechen_im_Verlauf}" />
                        </coding>
                    </valueCodeableConcept>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{$Ansprechen_ID}" />
            </request>
        </entry>
        <xsl:apply-templates select="./Histology">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
        </xsl:apply-templates>

        <xsl:apply-templates select="./TNM">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
        </xsl:apply-templates>

        <xsl:apply-templates select="./Metastasis">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
        </xsl:apply-templates>

    </xsl:template>


    <xsl:template match="TNM">
        <xsl:param name="Patient_ID" />
        <xsl:variable name="TNM_ID" select="mds2fhir:getID(./@TNM_ID, mds2fhir:transformDate(./Datum_der_TNM-Dokumentation-Datum_Befund), generate-id())" as="xs:string" />

        <entry>
            <fullUrl value="http://example.com/Observation/{$TNM_ID}" />
            <resource>
                <Observation>
                    <id value="{$TNM_ID}" />
                    <xsl:if test="./gesamtpraefix and ./gesamtpraefix !=''">
                    <meta>
                        <xsl:choose>
                            <xsl:when test="./gesamtpraefix='c'">
                                <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-TNMc" />
                            </xsl:when>
                            <xsl:when test="./gesamtpraefix='p'">
                                <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-TNMp" />
                            </xsl:when>
                        </xsl:choose>
                    </meta>
                </xsl:if>
                    <status value="final" />
                    <code>
                        <xsl:choose>
                            <xsl:when test="./gesamtpraefix and ./gesamtpraefix !=''">
                            <coding>
                                <system value="http://loinc.org" />
                                <code>
                                    <xsl:choose>
                                        <xsl:when  test="./gesamtpraefix='c'">
                                            <xsl:attribute name="value">21908-9</xsl:attribute>
                                        </xsl:when>
                                        <xsl:when test="./gesamtpraefix='p'">
                                            <xsl:attribute name="value">21902-2</xsl:attribute>
                                        </xsl:when>
                                    </xsl:choose>
                                </code>
                            </coding>
                            </xsl:when>
                        <xsl:otherwise>
                            <text value= "TNM ohne Angabe ob klinisch oder pthologisch"/>
                        </xsl:otherwise>
                    </xsl:choose>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <effectiveDateTime value="{mds2fhir:transformDate(./Datum_der_TNM-Dokumentation-Datum_Befund)}" />
                    <xsl:if test="./UICC_Stadium">
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/UiccstadiumCS" />
                                <code value="{./UICC_Stadium}" />
                            </coding>
                        </valueCodeableConcept>
                    </xsl:if>
                    <component>
                        <code>
                            <coding>
                                <system value="http://loinc.org" />
                                <code>
                                    <xsl:choose>
                                    <xsl:when test="./c-p-u-Präfix_T='c'">
                                        <xsl:attribute name="value">21905-5</xsl:attribute>
                                    </xsl:when>
                                    <xsl:when test="./c-p-u-Präfix_T='p'">
                                        <xsl:attribute name="value">21899-0</xsl:attribute>
                                    </xsl:when>
                                </xsl:choose>
                                </code> 
                            </coding>
                        </code>
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/TNMTCS" />
                                <code value="{./TNM-T}" />
                            </coding>
                        </valueCodeableConcept>
                    </component>
                    <component>
                        <code>
                            <coding>
                                <system value="http://loinc.org" />
                                <code>
                                    <xsl:choose>
                                    <xsl:when test="./c-p-u-Präfix_N='c'">
                                        <xsl:attribute name="value">201906-3</xsl:attribute>
                                    </xsl:when>
                                    <xsl:when test="./c-p-u-Präfix_N='p'">
                                        <xsl:attribute name="value">21900-6</xsl:attribute>
                                    </xsl:when>
                                </xsl:choose>
                                </code> 
                            </coding>
                        </code>
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/TNMNCS" />
                                <code value="{./TNM-N}" />
                            </coding>
                        </valueCodeableConcept>
                    </component>
                    <component>
                        <code>
                            <coding>
                                <system value="http://loinc.org" />
                                <code>
                                    <xsl:choose>
                                    <xsl:when test="./c-p-u-Präfix_M='c'">
                                        <xsl:attribute name="value">21907-1</xsl:attribute>
                                    </xsl:when>
                                    <xsl:when test="./c-p-u-Präfix_M='p'">
                                        <xsl:attribute name="value">21901-4</xsl:attribute>
                                    </xsl:when>
                                </xsl:choose>
                                </code> 
                            </coding>
                        </code>
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/TNMMCS" />
                                <code value="{./TNM-M}" />
                            </coding>
                        </valueCodeableConcept>
                    </component>
                    <component>
                        <code>
                            <coding>
                                <system value="http://loinc.org" />
                                <code value="59479-6" />
                            </coding>
                        </code>
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/TNMySymbolCS" />
                                <code>
                                    <xsl:choose>
                                        <xsl:when test="./TNM-y-Symbol='y'">
                                            <xsl:attribute name="value">y</xsl:attribute>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:attribute name="value">9</xsl:attribute>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </code>
                            </coding>
                        </valueCodeableConcept>
                    </component>
                    <component>
                        <code>
                            <coding>
                                <system value="http://loinc.org" />
                                <code value="21983-2" />
                            </coding>
                        </code>
                        <valueCodeableConcept>
                            <coding>
                                <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/TNMrSymbolCS" />
                                <code>
                                    <xsl:choose>
                                        <xsl:when test="./TNM-r-Symbol='r'">
                                            <xsl:attribute name="value">r</xsl:attribute>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:attribute name="value">9</xsl:attribute>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </code>
                            </coding>
                        </valueCodeableConcept>
                    </component>
                <xsl:if test="./TNM-m-Symbol">
                    <component>
                        <code>
                            <coding>
                                <system value="http://loinc.org" />
                                <code value="42030-7" />
                            </coding>
                        </code>
                        <valueString value="{./TNM-m-Symbol}" />
                    </component>
                </xsl:if>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{$TNM_ID}" />
            </request>
        </entry>


    </xsl:template>


    <xsl:template match="Metastasis">
        <xsl:param name="Patient_ID" />

        <xsl:variable name="Metastasis_ID" select="mds2fhir:getID(./@Metastasis_ID, '', generate-id())" as="xs:string" />
        <entry>
            <fullUrl value="http://example.com/Observation/{$Metastasis_ID}" />
            <resource>
                <Observation>
                    <id value="{$Metastasis_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-Fernmetastasen" />
                    </meta>
                    <status value="final" />
                    <code>
                        <coding>
                            <system value="http://loinc.org" />
                            <code value="21907-1" />
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <effectiveDateTime value="{mds2fhir:transformDate(../Verlauf/Datum_Verlauf)}" />
                    <xsl:if test="./Fernmetastasen_vorhanden">
                    <valueCodeableConcept>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/JNUCS" />
                            <xsl:choose>
                                <xsl:when test="./Fernmetastasen_vorhanden = 'nicht erfasst'">
                                <code value="U" />
                                </xsl:when>
                                <xsl:otherwise>
                                    <code value="{./Fernmetastasen_vorhanden}" />
                                 </xsl:otherwise>
                            </xsl:choose>
                        </coding>
                    </valueCodeableConcept>
                </xsl:if>
                <xsl:if test="./Lokalisation_Fernmetastasen">
                    <bodySite>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/FMLokalisationCS" />
                            <code value="{./Lokalisation_Fernmetastasen}" />
                        </coding>
                    </bodySite>
                    </xsl:if>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{$Metastasis_ID}" />
            </request>
        </entry>
    </xsl:template>

    <xsl:template match="Fernmetastase">
        <xsl:param name="Patient_ID" />

        <xsl:variable name="Metastasis_ID" select="mds2fhir:getID('', '', generate-id())" as="xs:string" />
        <entry>
            <fullUrl value="http://example.com/Observation/{$Metastasis_ID}" />
            <resource>
                <Observation>
                    <id value="{$Metastasis_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-Fernmetastasen" />
                    </meta>
                    <status value="final" />
                    <code>
                        <coding>
                            <system value="http://loinc.org" />
                            <code value="21907-1" />
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <effectiveDateTime value="{mds2fhir:transformDate(./FM_Diagnosedatum)}" />
                    <valueCodeableConcept>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/JNUCS" />
                            <code value="J" />
                        </coding>
                    </valueCodeableConcept>
                    <bodySite>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/FMLokalisationCS" />
                            <code value="{./FM_Lokalisation}" />
                        </coding>
                    </bodySite>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{$Metastasis_ID}" />
            </request>
        </entry>
    </xsl:template>


    <xsl:template match="Histology">
        <xsl:param name="Patient_ID" />

        <xsl:variable name="Histology_ID" select="mds2fhir:getID(./@Histology_ID, mds2fhir:transformDate(./Tumor_Histologiedatum), generate-id())" as="xs:string" />
        <xsl:variable name="Grading_ID" select="mds2fhir:getID(./@Histology_ID, '', generate-id())" as="xs:string"/>

        <entry>
            <fullUrl value="http://example.com/Observation/{$Histology_ID}" />
            <resource>
                <Observation>
                    <id value="{$Histology_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-Histologie" />
                    </meta>
                    <status value="final" />
                    <code>
                        <coding>
                            <system value="http://loinc.org" />
                            <code value="59847-4" />
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <valueCodeableConcept>
                        <coding>
                            <system value="urn:oid:2.16.840.1.113883.6.43.1" />
                            <version value="{./ICD-O_Katalog_Morphologie_Version}" />
                            <code value="{./Morphologie}" />
                        </coding>
                    </valueCodeableConcept>
                    <hasMember>
                        <reference value="Observation/{$Grading_ID}" />
                    </hasMember>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{$Histology_ID}" />
            </request>
        </entry>
        <entry>
            <fullUrl value="http://example.com/Observation/{$Grading_ID}" />
            <resource>
                <Observation>
                    <id value="{$Grading_ID}" />
                    <meta>
                        <profile value="http://dktk.dkfz.de/fhir/StructureDefinition/onco-core-Observation-Grading" />
                    </meta>
                    <status value="final" />
                    <code>
                        <coding>
                            <system value="http://loinc.org" />
                            <code value="59542-1" />
                        </coding>
                    </code>
                    <subject>
                        <reference value="Patient/{$Patient_ID}" />
                    </subject>
                    <valueCodeableConcept>
                        <coding>
                            <system value="http://dktk.dkfz.de/fhir/onco/core/CodeSystem/GradingCS" />
                            <code value="{./Grading}" />
                        </coding>
                    </valueCodeableConcept>
                </Observation>
            </resource>
            <request>
                <method value="PUT" />
                <url value="Observation/{$Grading_ID}" />
            </request>
        </entry>
    </xsl:template>


    <xsl:template match="Tumor" mode="tumor">
        <xsl:param name="Diagnosis_ID" />
        <xsl:param name="Patient_ID" />
        <xsl:variable name="Tumor_ID" select="mds2fhir:getID(./@Tumor_ID, '', generate-id())" as="xs:string" />

        <xsl:apply-templates select="./Histology">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
        </xsl:apply-templates>

        <xsl:apply-templates select="./Metastasis">
            <xsl:with-param name="Tumor_ID" select="$Tumor_ID" />
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
        </xsl:apply-templates>


        <xsl:apply-templates select="./TNM">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
        </xsl:apply-templates>

        <xsl:apply-templates select="./OP">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID" />
        </xsl:apply-templates>

        <xsl:apply-templates select="./ST">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID" />
        </xsl:apply-templates>

        <xsl:apply-templates select="./SYST">
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID" />
        </xsl:apply-templates>


        <xsl:apply-templates select="./Verlauf">
            <xsl:with-param name="Tumor_ID" select="$Tumor_ID" />
            <xsl:with-param name="Patient_ID" select="$Patient_ID" />
            <xsl:with-param name="Diagnosis_ID" select="$Diagnosis_ID" />
        </xsl:apply-templates>
    </xsl:template>




    <!-- Funktionen -->
    <!-- Generate Id if non exists. If possible, include some releated date to avoid collision & improve indexing. -->
    <xsl:function name="mds2fhir:getID">
        <xsl:param name="id" />
        <xsl:param name="date"/>
        <xsl:param name="prefix" />

        <xsl:sequence select="
            if ($id and $id != '') then
               $id
            else 
                if ($date and $date != '') then
                    concat($date,'-', $prefix)
                else $prefix
			" />
    </xsl:function>


    <xsl:function name="mds2fhir:transformDate">
        <xsl:param name="date" />
        <xsl:variable name="day" select="substring($date, 1,2)" as="xs:string" />
        <xsl:variable name="month" select="substring($date, 4, 2)" as="xs:string" />
        <xsl:variable name="year" select="substring($date, 7, 4)" as="xs:string" />
        <xsl:choose>
            <xsl:when test="$day='00'">
                <xsl:choose>
                    <xsl:when test="$month='00'">
                        <xsl:value-of select="$year" />
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="concat($year,'-',$month)" />
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="concat($year,'-',$month,'-',$day)" />
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="mds2fhir:getVersionYear">
        <xsl:param name="version" />
        <xsl:value-of select="substring($version, 4, 4)" />
    </xsl:function>

    <xsl:function name="mds2fhir:getICDType">
        <xsl:param name="version" />
        <xsl:choose>
            <xsl:when test="contains($version,'GM')">http://fhir.de/CodeSystem/dimdi/icd-10-gm</xsl:when>
            <xsl:when test="contains($version,'WHO')">http://hl7.org/fhir/sid/icd-10</xsl:when>
        </xsl:choose>
    </xsl:function>


</xsl:stylesheet>