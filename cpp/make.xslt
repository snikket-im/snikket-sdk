<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:param name="DIR" select="''"/>
  <xsl:output method="text" encoding="utf-8"/>

  <xsl:template match="/xml">

<xsl:for-each select="set[@name and @value]">
  <xsl:value-of select="@name"/>
  <xsl:text> = </xsl:text>
  <xsl:value-of select="@value"/>
  <xsl:text>
</xsl:text>
</xsl:for-each>

<xsl:text>CXXFLAGS += </xsl:text>
<xsl:value-of select="//compilerflag[1]/@value"/>
<xsl:text>
</xsl:text>

<xsl:text>LDFLAGS += </xsl:text>
<xsl:for-each select="//target/lib[not(@if)]">
  <xsl:text> </xsl:text>
  <xsl:value-of select="@name"/>
</xsl:for-each>
<xsl:text>
</xsl:text>

<xsl:text>SRCS += </xsl:text>
<xsl:for-each select="//files[not(@id='__main__') and not(@id='cppia') and not(@id='tracy')]//file[contains(@name,'.cpp') and not(@if) and not(@unless='HXCPP_TRACY')]">
<xsl:variable name="src">
  <xsl:choose>
    <xsl:when test="starts-with(@name,'${HXCPP}/')">
      <xsl:value-of select="substring-after(@name,'${HXCPP}/')"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="@name"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:variable>
  <xsl:value-of select="concat($DIR, $src)"/>
  <xsl:text> </xsl:text>
</xsl:for-each>
<xsl:text>
</xsl:text>

<!--
<xsl:for-each select="//files[not(@id='__main__') and not(@id='cppia') and not(@id='tracy')]//file[contains(@name,'.cpp') and not(@if) and not(@unless='HXCPP_TRACY')]">
<xsl:variable name="src">
  <xsl:choose>
    <xsl:when test="starts-with(@name,'${HXCPP}/')">
      <xsl:value-of select="substring-after(@name,'${HXCPP}/')"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="@name"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:variable>
  <xsl:variable name="obj" select="concat(substring-before($src,'.cpp'),'.o')"/>
  <xsl:value-of select="$obj"/>
  <xsl:text>: </xsl:text>
  <xsl:value-of select="concat($DIR, $src)"/>
  <xsl:for-each select="depend">
    <xsl:text> </xsl:text>
    <xsl:value-of select="@name"/>
  </xsl:for-each>
  <xsl:text>
</xsl:text>
</xsl:for-each>
-->

  </xsl:template>
</xsl:stylesheet>
