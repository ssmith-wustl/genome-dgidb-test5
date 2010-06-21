<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
  <xsl:template name="genome_model" match="object[./types[./isa[@type='Genome::Model']]]">
    <!-- These parameters are only valid when there is a last_complete_build; they are here for overriding by subclasses -->
    <xsl:param name="build_directory_url">
        <xsl:text>https://gscweb.gsc.wustl.edu/</xsl:text><xsl:value-of select="normalize-space(aspect[@name='last_complete_build']/object/aspect[@name='data_directory']/value)" />
    </xsl:param>
    <xsl:param name="summary_report_url">
        <xsl:value-of select="$build_directory_url"/><xsl:text>/reports/Summary/report.html</xsl:text>
    </xsl:param>

    <div class="result">
    <table width="100%" cellpadding="0" cellspacing="0" border="0" class="result"><tbody><tr>
      <td>
        <div class="icon">
          <xsl:call-template name="object_link">
            <xsl:with-param name="linktext">
              <img width="32" height="32" src="/res/old/report_resources/apipe_dashboard/images/icons/model_32.png" />
            </xsl:with-param>
          </xsl:call-template>
        </div>
      </td><td>
        <div class="description">
                <h2 class="name">
          <span class="label">
            Model:
          </span>
          <span class="title"> 
            <xsl:call-template name="object_link" /> (#<xsl:value-of select="@id"/>)
          </span>
        </h2>
        <p class="blurb">
           created on <xsl:value-of select="aspect[@name='creation_date']/value"/> by <xsl:value-of select="aspect[@name='user_name']/value"/>
        </p>
        <p class="info">
        <xsl:choose>
          <xsl:when test="aspect[@name='last_complete_build']/object">
            <xsl:for-each select="aspect[@name='last_complete_build']/object">
            <xsl:call-template name="object_link">
              <xsl:with-param name="linktext" select="'last succeeded build'" />
            </xsl:call-template>
            | <a><xsl:attribute name="href"><xsl:value-of select='$build_directory_url'/></xsl:attribute>data directory</a>
            | <a><xsl:attribute name="href"><xsl:value-of select="$summary_report_url"/></xsl:attribute>summary report</a>
            </xsl:for-each>
          </xsl:when>
          <xsl:otherwise>
            [No succeeded builds.]
          </xsl:otherwise>
        </xsl:choose>
        </p>
        <p class="info">
        Subject:
        <xsl:choose>
          <xsl:when test="substring(normalize-space(aspect[@name='subject_class_name']/value),1,3) != 'GSC'">
            <xsl:call-template name="object_link">
              <xsl:with-param name="type" select="normalize-space(aspect[@name='subject_class_name']/value)"/>
              <xsl:with-param name="id" select="normalize-space(aspect[@name='subject_id']/value)"/>
              <xsl:with-param name="linktext">
                <xsl:value-of select="normalize-space(aspect[@name='subject_class_name']/value)"/>:
                <xsl:value-of select="normalize-space(aspect[@name='subject_id']/value)"/>
              </xsl:with-param>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="normalize-space(aspect[@name='subject_class_name']/value)"/>:
            <xsl:value-of select="normalize-space(aspect[@name='subject_id']/value)"/>
          </xsl:otherwise>
        </xsl:choose>
        </p>
      </div>
      </td></tr></tbody></table>
    </div>
    <xsl:for-each select="aspect[@name='processing_profile']/object">
      <xsl:call-template name="genome_processingprofile"/>
    </xsl:for-each>
    
    <xsl:if test="count(aspect[@name='inputs']) > 0 ">
      <xsl:for-each select="aspect[@name='inputs']">
        <xsl:call-template name="genome_model_input_table"/>
      </xsl:for-each>
    </xsl:if>
    
    <xsl:if test="count(aspect[@name='to_models'] | aspect[@name='from_models']) > 0">
      <xsl:call-template name="genome_model_link_table"/>
    </xsl:if>
    
    <table id="model_list" class="list" width="100%" cellspacing="0" cellpadding="0" border="0" style="clear:both">
      <tr>
        <td class="subtable_cell">
          <xsl:call-template name="genome_model_build_table_section"/>
        </td>
      </tr>
    </table>
  </xsl:template>
  
  <xsl:template name="genome_model_link_table">
    <table class="info_table">
      <tr><th colspan="2">Model Links</th></tr>
      
      <xsl:for-each select="aspect[@name='to_models']/object | aspect[@name='to_builds']/object">
        <xsl:call-template name="genome_model_link_table_row">
          <xsl:with-param name="type">to</xsl:with-param>
        </xsl:call-template>
      </xsl:for-each>
      <xsl:for-each select="aspect[@name='from_models']/object | aspect[@name='from_builds']/object">
        <xsl:call-template name="genome_model_link_table_row">
          <xsl:with-param name="type">from</xsl:with-param>
        </xsl:call-template>          
      </xsl:for-each>      
    </table>
  </xsl:template>
  
  <xsl:template name="genome_model_link_table_row">
     <xsl:param name="type" select="''" />
     <tr>
       <td class="label"><xsl:value-of select="$type"/></td>
       <td class="value">
         <xsl:call-template name="object_link">
           <xsl:with-param name="linktext">
             <xsl:value-of select="@type"/><xsl:text>: </xsl:text>
             <xsl:choose>
               <xsl:when test="aspect[@name='name']/value">
                 <xsl:value-of select="aspect[@name='name']/value"/> (#<xsl:value-of select="@id"/>)
               </xsl:when>
               <xsl:otherwise>
                 <xsl:value-of select="@id"/>
               </xsl:otherwise>
             </xsl:choose>
           </xsl:with-param>
         </xsl:call-template>
       </td>
     </tr>
  </xsl:template>
  
  <xsl:template name="genome_model_input_table">
    <table class="info_table">
      <tr><th colspan="2">Inputs</th></tr>
      <xsl:for-each select="object[aspect[@name='name']/value!='instrument_data']">
        <xsl:sort select="aspect[@name='name']/value" data-type="text" order="ascending"/>
        <xsl:call-template name="genome_model_input_table_row"/>
      </xsl:for-each>
      
      <!-- It has been decided that instrument_data should be last -->
      <xsl:for-each select="object[aspect[@name='name']/value='instrument_data']">
        <xsl:sort select="aspect[@name='name']/value" data-type="text" order="ascending"/>
        <xsl:call-template name="genome_model_input_table_row"/>
      </xsl:for-each>
    </table>
  </xsl:template>
  
  <xsl:template name="genome_model_input_table_row">
          <tr>
          <td class="label"><xsl:value-of select="normalize-space(aspect[@name='name']/value)"/>:</td>
          <td class="value">
            <xsl:call-template name="object_link">
              <xsl:with-param name="linktext">
                <xsl:value-of select="aspect[@name='value_class_name']/value"/>: <xsl:value-of select="aspect[@name='value_id']/value"/>
              </xsl:with-param>
              <xsl:with-param name="id">
                <xsl:value-of select="aspect[@name='value_id']/value"/>
              </xsl:with-param>
              <xsl:with-param name="type">
                <xsl:value-of select="aspect[@name='value_class_name']/value"/>
              </xsl:with-param>
            </xsl:call-template>
          </td>
        </tr>
  </xsl:template>

  <xsl:template name="genome_model_build_table_row">
    <tr onmouseover="this.className = 'hover'" onmouseout="this.className=''">
    <xsl:attribute name="onclick">
      <xsl:text>javascript:document.location.href='</xsl:text>
      <xsl:call-template name="object_link_href" />
        <xsl:text>'</xsl:text>
      </xsl:attribute>
      <td>
        
      </td>
      <td>
        <xsl:call-template name="object_link">
          <xsl:with-param name="linktext"><xsl:value-of select="@id"/></xsl:with-param>
        </xsl:call-template>
      </td>
      <td><xsl:attribute name="class"><xsl:text>status </xsl:text><xsl:value-of select="aspect[@name='status']/value"/></xsl:attribute>
        <xsl:value-of select="aspect[@name='status']/value"/>
      </td>
      <td>
        <xsl:value-of select="aspect[@name='date_scheduled']/value"/>
      </td>
      <td>
        <xsl:value-of select="aspect[@name='date_completed']/value"/>
      </td>
    </tr>
  </xsl:template>

  <xsl:template name="genome_model_build_table_section">
  <table width="100%" cellpadding="0" cellspacing="0" border="0" class="subtable">
      <colgroup>
        <col width="25%" />
        <col width="15%"/>
        <col width="15%"/>
        <col width="15%"/>
        <col width="15%"/>
        <col width="15%"/>
      </colgroup>
      <thead>
        <th class="subtable_label">BUILDS</th>
        <th>build id</th>
        <th>status</th>
        <th>date scheduled</th>
        <th>date completed</th>
      </thead>
      <tbody>
        <xsl:choose>
          <xsl:when test="count(aspect[@name='builds']/object) > 0">
            <xsl:for-each select="aspect[@name='builds']/object">
              <xsl:call-template name="genome_model_build_table_row" />
            </xsl:for-each>
          </xsl:when>
          <xsl:when test="count(aspect[@name='last_succeeded_build']/object) > 0" >
            <xsl:for-each select="aspect[@name='last_succeeded_build']/object">
              <xsl:call-template name="genome_model_build_table_row" />
            </xsl:for-each>
          </xsl:when>
          <xsl:when test="count(aspect[@name='last_complete_build']/object) > 0" >
            <xsl:for-each select="aspect[@name='last_complete_build']/object">
              <xsl:call-template name="genome_model_build_table_row" />
            </xsl:for-each>
          </xsl:when>
          <xsl:otherwise>
            <tr>
              <td></td>
              <td colspan="5">
                <strong>No builds found for this model.</strong>
              </td>
            </tr>
          </xsl:otherwise>
        </xsl:choose>
      </tbody>
    </table>
  </xsl:template>

  <xsl:template name="genome_model_build_table">
    <xsl:param name="want_builds" select="1" />
    <!-- Called on a node containing one or more object nodes of type model -->
    <table id="model_list" class="list" width="100%" cellspacing="0" cellpadding="0" border="0" style="clear:both">
      <colgroup>
        <col width="40%" />
        <col />
        <col />
        <col />
      </colgroup>
      <tbody>
        <xsl:for-each select="object[./types[./isa[@type='Genome::Model']]]">
          <xsl:sort select="aspect[@name='name']/value" data-type="text" order="ascending"/>
          <xsl:variable name="is_default" select="aspect[@name='is_default']/value" />
          <tr class="model_row_header">
            <td class="model_name">
              <xsl:if test="$is_default = 1">
                <!-- if this is the default model, show a nice little star -->
                <img class="default_report_star" src="/res/old/report_resources/apipe_dashboard/images/icons/star_16.png" width="16" height="16" absmiddle="middle" alt="Default Model"/>
              </xsl:if>
              <xsl:call-template name="object_link"/>
            </td>
            <td>
              <strong>model id: </strong><xsl:value-of select="@id"/>
            </td>
            <td><strong>username: </strong><xsl:value-of select="aspect[@name='user_name']/value"/></td>
            <td class="last"><strong>scheduled: </strong><xsl:value-of select="aspect[@name='creation_date']/value"/></td>
          </tr>
          <xsl:if test="$want_builds = 1">
            <tr>
              <td colspan="4" class="subtable_cell">
                <xsl:call-template name="genome_model_build_table_section"/>
              </td>
            </tr>
          </xsl:if>
        </xsl:for-each>
      </tbody>
    </table>
  </xsl:template>

</xsl:stylesheet>