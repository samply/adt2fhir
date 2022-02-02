<?xml version="1.0" encoding="utf-8" standalone="no"?>
<xsl:stylesheet 
    xmlns="http://www.gekid.de/namespace"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    exclude-result-prefixes="#default" 
    version="2.0"
    xpath-default-namespace="http://www.gekid.de/namespace">
    
    <xsl:output encoding="UTF-8" indent="yes" method="xml"/>
    <xsl:output omit-xml-declaration="no" indent="yes"/>
    <xsl:strip-space elements="*"/>

    <xsl:template match="/ADT_GEKID">
        <xsl:for-each select="Menge_Patient/Patient">
            <!-- <xsl:result-document method="xml" href="file:C:\Workspace\tmp\singleADT\Patient_{Patienten_Stammdaten/@Patient_ID}.xml"> -->
            <xsl:result-document method="xml" href=".\ADT_Patients\Patient_{Patienten_Stammdaten/@Patient_ID}.xml">
                <ADT_GEKID Schema_Version="2.2.1">
                    <xsl:copy-of select="/ADT_GEKID/@*" />
                    <Menge_Patient>
                        <xsl:copy-of select="../@* | ." />
                    </Menge_Patient>
                </ADT_GEKID>
                </xsl:result-document>
        </xsl:for-each>
    </xsl:template> 
    
</xsl:stylesheet>
