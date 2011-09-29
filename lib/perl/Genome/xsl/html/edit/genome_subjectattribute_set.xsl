<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:template name="genome_subjectattribute_set" match="object[./types[./isa[@type='Genome::SubjectAttribute::Set']]]">

    <script type="text/javascript" src="/res/js/pkg/dataTables/media/js/jquery.dataTables.js"></script>

    <script type="text/javascript" language="javascript"></script>

    <xsl:call-template name="control_bar_view"/>

    <xsl:call-template name="view_header">
      <xsl:with-param name="label_name" select="'Sample:'" />
      <xsl:with-param name="display_name" select="aspect[@name='name']/value" />
      <xsl:with-param name="icon" select="'genome_sample_32'" />
    </xsl:call-template>

    <div class="content rounded shadow">
      <div class="container">

            <!-- details for this sample -->
            <table id="samples" class="lister">
                <thead>
                    <tr>
                        <th>key</th>
                        <th>value</th>
                    </tr>
                </thead>
                <tbody>
<!--                    <xsl:for-each select="/object/aspect[@name='members']/object">
-->
                    <xsl:for-each select="/object/aspect[@name='members']/object[1]/aspect[@name='all_nomenclature_fields']/object">
                        <xsl:variable name='field_name' select="aspect[@name='name']/value"/>
                        <xsl:variable name='field_type' select="aspect[@name='type']/value"/>
                        <xsl:variable name='field_value' select="/object/aspect[@name='members']/object/aspect[value = $field_name]/../aspect[@name='attribute_value']/value"/>
                    <tr>
                        <td>
                            <xsl:value-of select="$field_name"/>
                        </td>
                        <td>
                            <xsl:choose>
                                <xsl:when test="$field_type = 'enumerated'">
                                    <select>
                                        <xsl:for-each select="aspect[@name='enumerated_values']/object">
                                            <option> 
                                                <xsl:if test="$field_value = aspect[@name='value']/value"> 
                                                    <xsl:attribute name="selected">true</xsl:attribute> 
                                                </xsl:if>
                                                <xsl:value-of select="aspect[@name='value']/value"/> 
                                            </option>
                                        </xsl:for-each>
                                    </select>
                                </xsl:when> 
                                <xsl:otherwise>
                                    <input> <xsl:attribute name="value"><xsl:value-of select="$field_value"/> </xsl:attribute> </input>
                                </xsl:otherwise>
                            </xsl:choose>         
                        </td>
                    </tr>
                    </xsl:for-each>
                    <tr><td></td><td><button>save</button></td></tr>
                </tbody>
            </table>

      </div> <!-- end container -->
    </div> <!-- end content -->

    <xsl:call-template name="footer">
      <xsl:with-param name="footer_text">
        <br/>
      </xsl:with-param>
    </xsl:call-template>

  </xsl:template>

</xsl:stylesheet>



