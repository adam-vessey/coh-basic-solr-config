<?xml version="1.0" encoding="UTF-8"?>
<!-- Basic MODS -->
<xsl:stylesheet version="1.0"
  xmlns:java="http://xml.apache.org/xalan/java"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:foxml="info:fedora/fedora-system:def/foxml#"
  xmlns:mods="http://www.loc.gov/mods/v3"
     exclude-result-prefixes="mods java">
  <!-- <xsl:include href="/usr/local/fedora/tomcat/webapps/fedoragsearch/WEB-INF/classes/config/index/FgsIndex/islandora_transforms/library/xslt-date-template.xslt"/>-->
  <xsl:include href="/usr/local/fedora/tomcat/webapps/fedoragsearch/WEB-INF/classes/fgsconfigFinal/index/FgsIndex/islandora_transforms/library/xslt-date-template.xslt"/>
  <!-- <xsl:include href="/usr/local/fedora/tomcat/webapps/fedoragsearch/WEB-INF/classes/config/index/FgsIndex/islandora_transforms/manuscript_finding_aid.xslt"/> -->
  <xsl:include href="/usr/local/fedora/tomcat/webapps/fedoragsearch/WEB-INF/classes/fgsconfigFinal/index/FgsIndex/islandora_transforms/manuscript_finding_aid.xslt"/>
  <!-- HashSet to track single-valued fields. -->
  <xsl:variable name="single_valued_hashset" select="java:java.util.HashSet.new()"/>

  <xsl:template match="foxml:datastream[@ID='MODS']/foxml:datastreamVersion[last()]" name="index_MODS">
    <xsl:param name="content"/>
    <xsl:param name="prefix"></xsl:param>
    <xsl:param name="suffix">ms</xsl:param>

    <xsl:apply-templates mode="slurping_MODS" select="$content//mods:mods[1]">
      <xsl:with-param name="prefix" select="$prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="pid" select="../../@PID"/>
      <xsl:with-param name="datastream" select="../@ID"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- Handle dates. -->
  <xsl:template match="mods:*[(@type='date') or (contains(translate(local-name(), 'D', 'd'), 'date'))][normalize-space(text())]" mode="slurping_MODS">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="pid">not provided</xsl:param>
    <xsl:param name="datastream">not provided</xsl:param>

    <xsl:variable name="rawTextValue" select="normalize-space(text())"/>

    <xsl:variable name="textValue">
      <xsl:call-template name="get_ISO8601_date">
        <xsl:with-param name="date" select="$rawTextValue"/>
        <xsl:with-param name="pid" select="$pid"/>
        <xsl:with-param name="datastream" select="$datastream"/>
      </xsl:call-template>
    </xsl:variable>

    <!-- Use attributes in field name. -->
    <xsl:variable name="this_prefix">
      <xsl:value-of select="$prefix"/>
      <xsl:for-each select="@*">
        <xsl:sort select="concat(local-name(), namespace-uri(self::node()))"/>
        <xsl:value-of select="local-name()"/>
        <xsl:text>_</xsl:text>
        <xsl:value-of select="."/>
        <xsl:text>_</xsl:text>
      </xsl:for-each>
    </xsl:variable>

    <!-- Prevent multiple generating multiple instances of single-valued fields
         by tracking things in a HashSet -->
    <xsl:variable name="field_name" select="normalize-space(concat($this_prefix, local-name()))"/>
    <!-- The method java.util.HashSet.add will return false when the value is
         already in the set. -->
    <xsl:if test="java:add($single_valued_hashset, $field_name)">
      <xsl:if test="not(normalize-space($textValue)='')">
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($field_name, '_dt')"/>
          </xsl:attribute>
          <xsl:value-of select="$textValue"/>
        </field>
      </xsl:if>
      <xsl:if test="not(normalize-space($rawTextValue)='')">
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="concat($field_name, '_s')"/>
          </xsl:attribute>
          <xsl:value-of select="$rawTextValue"/>
        </field>
      </xsl:if>
    </xsl:if>

    <xsl:if test="not(normalize-space($textValue)='')">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_mdt')"/>
        </xsl:attribute>
        <xsl:value-of select="$textValue"/>
      </field>
    </xsl:if>
    <xsl:if test="not(normalize-space($rawTextValue)='')">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_ms')"/>
        </xsl:attribute>
        <xsl:value-of select="$rawTextValue"/>
      </field>
    </xsl:if>
  </xsl:template>

  <!-- Avoid using text alone. -->
  <xsl:template match="text()" mode="slurping_MODS"/>

  <!-- Build up the list prefix with the element context. -->
  <xsl:template match="*" mode="slurping_MODS">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="pid">not provided</xsl:param>
    <xsl:param name="datastream">not provided</xsl:param>
    <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz_'" />
    <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ '" />

    <xsl:variable name="this_prefix">
      <xsl:value-of select="concat($prefix, local-name(), '_')"/>
      <xsl:if test="@type">
        <xsl:value-of select="concat(@type, '_')"/>
      </xsl:if>
    </xsl:variable>

    <xsl:call-template name="mods_authority_fork">
      <xsl:with-param name="prefix" select="$this_prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="normalize-space(text())"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
    </xsl:call-template>
  </xsl:template>

  <!-- Aggregate values in subjects into a single value. -->
  <xsl:template match="*[ancestor::mods:subject]" mode="slurping_MODS">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="pid">not provided</xsl:param>
    <xsl:param name="datastream">not provided</xsl:param>

    <xsl:variable name="aggregating_part">coh_aggregated_</xsl:variable>
    <!-- We are aggregating if the prefix ends a certain way... -->
    <xsl:variable name="aggregating" select="$aggregating_part = substring($prefix, string-length($prefix) - string-length($aggregating_part) + 1)"/>

    <!-- Continue to process normally (if not in the process of aggregating).-->
    <xsl:call-template name="mods_authority_fork">
      <xsl:with-param name="prefix">
        <xsl:value-of select="$prefix"/>
        <xsl:if test="not($aggregating)">
          <xsl:value-of select="local-name()"/>
          <xsl:text>_</xsl:text>
          <xsl:if test="@type">
            <xsl:value-of select="concat(@type, '_')"/>
          </xsl:if>
        </xsl:if>
      </xsl:with-param>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="normalize-space(text())"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
    </xsl:call-template>
  </xsl:template>

  <!-- Aggregate values in subjects into a single value. -->
  <xsl:template match="mods:subject/mods:*" mode="slurping_MODS">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="pid">not provided</xsl:param>
    <xsl:param name="datastream">not provided</xsl:param>

    <xsl:call-template name="mods_authority_fork">
      <xsl:with-param name="prefix">
        <xsl:value-of select="$prefix"/>
        <xsl:text>coh_aggregated_</xsl:text>
      </xsl:with-param>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="normalize-space(text())"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
    </xsl:call-template>

    <!-- Continue processing normally. -->
    <xsl:variable name="this_prefix">
      <xsl:value-of select="concat($prefix, local-name(), '_')"/>
      <xsl:if test="@type">
        <xsl:value-of select="concat(@type, '_')"/>
      </xsl:if>
    </xsl:variable>

    <xsl:call-template name="mods_authority_fork">
      <xsl:with-param name="prefix" select="$this_prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="normalize-space(text())"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="mods:mods" mode="slurping_MODS">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="pid">not provided</xsl:param>
    <xsl:param name="datastream">not provided</xsl:param>

    <!-- Recurse as normal, so we are sure to get the regular fields. -->
    <xsl:variable name="this_prefix" select="concat($prefix, local-name(), '_')"/>
    <xsl:call-template name="general_mods_field">
      <xsl:with-param name="prefix" select="$this_prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="normalize-space(text())"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
    </xsl:call-template>

    <!-- Need to be able to use some fields differently, depending on what the
      MODS is describing. -->
    <xsl:variable name="genre" select="normalize-space(mods:genre)"/>
    <xsl:choose>
      <xsl:when test="$genre='book' or $genre='book chapter'">
        <xsl:call-template name="general_mods_field">
          <xsl:with-param name="prefix" select="concat($this_prefix, 'book_')"/>
          <xsl:with-param name="suffix" select="$suffix"/>
          <xsl:with-param name="value" select="normalize-space(text())"/>
          <xsl:with-param name="pid" select="$pid"/>
          <xsl:with-param name="datastream" select="$datastream"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:when test="$genre='journal article'">
        <xsl:call-template name="general_mods_field">
          <xsl:with-param name="prefix" select="concat($this_prefix, 'journal_article_')"/>
          <xsl:with-param name="suffix" select="$suffix"/>
          <xsl:with-param name="value" select="normalize-space(text())"/>
          <xsl:with-param name="pid" select="$pid"/>
          <xsl:with-param name="datastream" select="$datastream"/>
        </xsl:call-template>
      </xsl:when>
    </xsl:choose>
  </xsl:template>
  <xsl:template match="mods:subject[@authority='ccsg' and mods:topic='0']" mode="slurping_MODS"/>
  <xsl:template match="mods:subject[@authority='ccsg']/mods:topic" mode="slurping_MODS"/>
  <xsl:template match="mods:subject[@authority='ccsg' and mods:topic='1']" mode="slurping_MODS">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="pid">not provided</xsl:param>
    <xsl:param name="datastream">not provided</xsl:param>
    <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz_'" />
    <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ '" />

    <!-- Produce a "masked" copy of the field, which only contains those values
      which have not been "excluded". -->
    <xsl:variable name="type" select="normalize-space(mods:titleInfo[@type='abbreviated']/mods:title)"/>
    <xsl:if test="normalize-space(../mods:note[@type=concat('exclude ', $type)]) = '0'">
      <xsl:variable name="this_prefix">
        <xsl:value-of select="concat($prefix, local-name(), '_')"/>
        <xsl:if test="@type">
          <xsl:value-of select="concat(@type, '_')"/>
        </xsl:if>
        <xsl:text>masked_</xsl:text>
      </xsl:variable>

      <xsl:call-template name="mods_authority_fork">
        <xsl:with-param name="prefix" select="$this_prefix"/>
        <xsl:with-param name="suffix" select="$suffix"/>
        <xsl:with-param name="value" select="normalize-space(text())"/>
        <xsl:with-param name="pid" select="$pid"/>
        <xsl:with-param name="datastream" select="$datastream"/>
      </xsl:call-template>
    </xsl:if>

    <!-- Proceed with normal processing. -->
    <xsl:variable name="this_prefix">
      <xsl:value-of select="concat($prefix, local-name(), '_')"/>
      <xsl:if test="@type">
        <xsl:value-of select="concat(@type, '_')"/>
      </xsl:if>
    </xsl:variable>

    <xsl:call-template name="mods_authority_fork">
      <xsl:with-param name="prefix" select="$this_prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="normalize-space(text())"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template match="mods:note[starts-with(@type, 'exclude ')][normalize-space(.) = '1']" mode="slurping_MODS">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>

    <xsl:variable name="program" select="substring-after(@type, 'exclude ')"/>
    <xsl:variable name="type" select="@type"/>
    <xsl:variable name="reason" select="normalize-space(../mods:note[@type = concat($type, ' reason')])"/>

    <xsl:if test="../mods:subject[@authority='ccsg'][normalize-space(mods:topic) = '1']/mods:titleInfo[@type='abbreviated']/mods:title[normalize-space(.) = substring-after($type, 'exclude ')]">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="$prefix"/>
          <xsl:text>ccsg_exclude_</xsl:text>
          <xsl:value-of select="$suffix"/>
        </xsl:attribute>
        <xsl:value-of select="$program"/>
      </field>
      <xsl:if test="$reason">
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="$prefix"/>
            <xsl:text>ccsg_exclude_reason</xsl:text>
            <xsl:value-of select="$suffix"/>
          </xsl:attribute>
          <xsl:value-of select="$reason"/>
        </field>
        <field>
          <xsl:attribute name="name">
            <xsl:value-of select="$prefix"/>
            <xsl:text>ccsg_exclude_reason_</xsl:text>
            <xsl:value-of select="$program"/>
            <xsl:text>_</xsl:text>
            <xsl:value-of select="$suffix"/>
          </xsl:attribute>
          <xsl:value-of select="$reason"/>
        </field>
      </xsl:if>
    </xsl:if>
  </xsl:template>

  <!-- Intercept names with role terms, so we can create copies of the fields
    including the role term in the name of generated fields. (Hurray, additional
    specificity!) -->
  <xsl:template match="mods:name[mods:role/mods:roleTerm]" mode="slurping_MODS">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="pid">not provided</xsl:param>
    <xsl:param name="datastream">not provided</xsl:param>
    <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz_'" />
    <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ '" />

    <xsl:variable name="base_prefix">
      <xsl:value-of select="concat($prefix, local-name(), '_')"/>
      <xsl:if test="@type">
        <xsl:value-of select="concat(@type, '_')"/>
      </xsl:if>
    </xsl:variable>
    <xsl:variable name="text_value" select="normalize-space(.)"/>
    <xsl:for-each select="mods:role/mods:roleTerm[normalize-space(.)]">
      <xsl:variable name="this_prefix" select="concat($base_prefix, translate(., $uppercase, $lowercase), '_')"/>

      <xsl:call-template name="mods_name_value_fork">
        <xsl:with-param name="prefix" select="$this_prefix"/>
        <xsl:with-param name="suffix" select="$suffix"/>
        <xsl:with-param name="value" select="$text_value"/>
        <xsl:with-param name="pid" select="$pid"/>
        <xsl:with-param name="datastream" select="$datastream"/>
        <xsl:with-param name="node" select="../.."/>
      </xsl:call-template>
    </xsl:for-each>

    <xsl:call-template name="mods_name_value_fork">
      <xsl:with-param name="prefix" select="$base_prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="$text_value"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="mods_name_value_fork">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="value"/>
    <xsl:param name="pid">not provided</xsl:param>
    <xsl:param name="datastream">not provided</xsl:param>
    <xsl:param name="node" select="current()"/>

    <!-- Generate field with complete name... Will end up creating other fields
      we won't really care about, but anyway. -->
    <xsl:variable name="family" select="normalize-space($node/mods:namePart[@type='family'][1])"/>
    <xsl:variable name="given" select="normalize-space($node/mods:namePart[@type='given'][1])"/>
    <xsl:variable name="complete_name">
      <xsl:choose>
        <xsl:when test="$family and $given">
          <xsl:value-of select="$family"/>
          <xsl:text>, </xsl:text>
          <xsl:call-template name="mods_given_name_rendering">
            <xsl:with-param name="value" select="$given"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:when test="$family">
          <xsl:value-of select="$family"/>
        </xsl:when>
        <xsl:when test="$given">
          <xsl:call-template name="mods_given_name_rendering">
            <xsl:with-param name="value" select="$given"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:for-each select="$node/mods:namePart[normalize-space(.)]">
            <xsl:if test="position() > 1">
              <xsl:text> </xsl:text>
            </xsl:if>
            <xsl:value-of select="normalize-space(.)"/>
          </xsl:for-each>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="normalize-space($complete_name)">
      <xsl:call-template name="mods_authority_fork">
        <xsl:with-param name="prefix" select="concat($prefix, 'coh_complete_name_')"/>
        <xsl:with-param name="suffix" select="$suffix"/>
        <xsl:with-param name="value" select="normalize-space($complete_name)"/>
        <xsl:with-param name="pid" select="$pid"/>
        <xsl:with-param name="datastream" select="$datastream"/>
      </xsl:call-template>
    </xsl:if>

    <!-- Proceed with normal processing. -->
    <xsl:call-template name="mods_authority_fork">
      <xsl:with-param name="prefix" select="$prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="$value"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
      <xsl:with-param name="node" select="$node"/>
    </xsl:call-template>
  </xsl:template>

  <!-- Render a given name of one character followed by a period, to represent
    initials.
  -->
  <xsl:template name="mods_given_name_rendering">
    <xsl:param name="value"/>

    <xsl:value-of select="$value"/>
    <xsl:if test="string-length($value) = 1">
      <xsl:text>.</xsl:text>
    </xsl:if>
  </xsl:template>

  <!-- Fields are duplicated for authority because searches across authorities are common. -->
  <xsl:template name="mods_authority_fork">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="value"/>
    <xsl:param name="pid">not provided</xsl:param>
    <xsl:param name="datastream">not provided</xsl:param>
    <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz_'" />
    <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ '" />

    <xsl:call-template name="general_mods_field">
      <xsl:with-param name="prefix" select="$prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value" select="$value"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
    </xsl:call-template>

    <!-- Fields are duplicated for authority because searches across authorities are common. -->
    <xsl:if test="@authority">
      <xsl:call-template name="general_mods_field">
        <xsl:with-param name="prefix" select="concat($prefix, 'authority_', translate(@authority, $uppercase, $lowercase), '_')"/>
        <xsl:with-param name="suffix" select="$suffix"/>
        <xsl:with-param name="value" select="$value"/>
        <xsl:with-param name="pid" select="$pid"/>
        <xsl:with-param name="datastream" select="$datastream"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!-- Handle the actual indexing of the majority of MODS elements, including
    the recursive step of kicking off the indexing of subelements. -->
  <xsl:template name="general_mods_field">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="value"/>
    <xsl:param name="pid"/>
    <xsl:param name="datastream"/>
    <xsl:param name="node" select="current()"/>

    <xsl:if test="$value">
      <field>
        <xsl:attribute name="name">
          <xsl:choose>
            <!-- Try to create a single-valued version of each field (if one
              does not already exist, that is). -->
            <!-- XXX: We make some assumptions about the schema here...
              Primarily, _s getting copied to the same places as _ms. -->
            <xsl:when test="$suffix='ms' and java:add($single_valued_hashset, string($prefix))">
              <xsl:value-of select="concat($prefix, 's')"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="concat($prefix, $suffix)"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
        <xsl:value-of select="$value"/>
      </field>
    </xsl:if>
    <xsl:if test="normalize-space($node/@authorityURI)">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, 'authorityURI_', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="$node/@authorityURI"/>
      </field>
    </xsl:if>

    <xsl:apply-templates select="$node/*" mode="slurping_MODS">
      <xsl:with-param name="prefix" select="$prefix"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="pid" select="$pid"/>
      <xsl:with-param name="datastream" select="$datastream"/>
    </xsl:apply-templates>
  </xsl:template>
</xsl:stylesheet>
