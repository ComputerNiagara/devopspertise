<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl">
  <xsl:output method="xml" indent="yes"/>

  <xsl:variable name="NumberOfItems" select="count(OWASPZAPReport/site/alerts/alertitem)"/>
  
  <xsl:template match="/">
    <test-run id="1" name="OWASPReport" fullname="OWASPReport" testcasecount="{$NumberOfItems}" result="Failed" total="{$NumberOfItems}" passed="0" failed="{$NumberOfItems}" inconclusive="0" skipped="0" asserts="0" engine-version="3.9.0.0" clr-version="4.0.30319.42000" start-time="" end-time="" duration="0">
	  <test-suite type="Assembly" id="0-1000" name="Test" fullname="OWASPResults.Test" classname="OWASPResults.Test" runstate="Runnable" testcasecount="{$NumberOfItems}" result="Failed" site="Child" start-time="" end-time="" duration="0" total="{$NumberOfItems}" passed="0" failed="{$NumberOfItems}" warnings="0" inconclusive="0" skipped="0" asserts="0">
		<xsl:for-each select="OWASPZAPReport/site/alerts/alertitem">
		<test-case id="0-1001" name="{name}" fullname="{name}" methodname="Stub" classname="OWASPResults.Test" runstate="NotRunnable" seed="12345" result="Failed" label="Invalid" start-time="" end-time="" duration="0" asserts="0">
		  <failure>
			<message>
			<xsl:text>Risk: </xsl:text><xsl:value-of select="riskdesc"/>
			<xsl:text>&#xa;Confidence: </xsl:text><xsl:value-of select="confidencedesc"/>
			<xsl:text>&#xa;&#xa;Description:</xsl:text><xsl:value-of select="desc"/>
			<xsl:text>&#xa;Solution:</xsl:text><xsl:value-of select="solution"/>
			<xsl:text>&#xa;Reference(s):</xsl:text><xsl:value-of select="reference"/>
			</message>
			<stack-trace>
			  <xsl:for-each select="instances/instance">
				<xsl:if test="uri != ''">
        	<xsl:text>Uri: </xsl:text><xsl:value-of select="uri"/>
    			</xsl:if>
				<xsl:if test="method != ''">
        	<xsl:text>&#xa;Method: </xsl:text> <xsl:value-of select="method"/>
    			</xsl:if>
				<xsl:if test="param != ''">
        	<xsl:text>&#xa;Param: </xsl:text> <xsl:value-of select="param"/>
    			</xsl:if>
				<xsl:if test="attack != ''">
        	<xsl:text>&#xa;Attack: </xsl:text> <xsl:value-of select="attack"/>
    			</xsl:if>
				<xsl:if test="evidence != ''">
        	<xsl:text>&#xa;Evidence: </xsl:text> <xsl:value-of select="evidence"/>
    			</xsl:if>
				<xsl:if test="otherinfo != ''">
        	<xsl:text>&#xa;Info: </xsl:text> <xsl:value-of select="otherinfo"/>
    			</xsl:if>
			-
			  </xsl:for-each>
			</stack-trace>
		  </failure>
		</test-case>
		</xsl:for-each>
	  </test-suite>
    </test-run>
  </xsl:template>
</xsl:stylesheet>