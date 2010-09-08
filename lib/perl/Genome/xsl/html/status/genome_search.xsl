<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">


  <xsl:template name="genome_search" match="object[./types[./isa[@type='Genome::Search']]]">

    <xsl:call-template name="control_bar_app"/>

    <div class="content rounded shadow" style="padding-top: 0;">
      <xsl:call-template name="app_header">
        <xsl:with-param name="app_name" select="'Analysis Search'"/>
        <xsl:with-param name="icon" select="'app_analysis_search_32'"/>
      </xsl:call-template>

      <div class="container">
        <div class="span-12">
          <div class="main_search">
            <form method="get" action="/view/genome/search/query/status.html">
              <h4>Please enter your search, then press Return:</h4>

              <table cellpadding="0" cellspacing="0" border="0" class="search_elements">
                <tr>
                  <td>
                    <input class="query_box rounded" type="text" name="query"/>
                  </td>
                  <td>
                    <input type="submit" class="button" value="Search"/>
                  </td>
                </tr>
              </table>
            </form>
          </div>

        </div> <!-- end .span-12 -->
        <div class="span-12 last">
          <br/>
        </div>
        <hr class="space"/>
        <div class="main_search_hints clearfix">
          <div class="box_header span-8 last rounded-top">
            <div class="box_title"><h3 class="nontyped span-7 last">Indexed Pipeline Artifacts</h3></div>
            <div class="box_button">

            </div>
          </div>

          <div class="box_content rounded-bottom span-24 last">
            <div style="width: 50%; float: left;">
              <div class="padding10">

                <div class="search_result">
                  <div class="result_icon genome_disk_group_32">
                    <br/>
                  </div>
                  <div class="result">
                    <h3>Disk Groups</h3>
                    <p class="result_summary">
                      Disk groups are collections of disk volumes grouped together according to their usage (e.g. illumina sequencing, alignment).
                    </p>
                  </div>
                </div> <!-- end search_result -->

                <div class="search_result">
                  <div class="result_icon genome_disk_volume_32">
                    <br/>
                  </div>
                  <div class="result">
                    <h3>Disk Volumes</h3>
                    <p class="result_summary">
                      A single filesystem, assigned to a group.
                    </p>
                  </div>
                </div> <!-- end search_result -->


                <div class="search_result">
                  <div class="result_icon genome_sys_email_32">
                    <br/>
                  </div>
                  <div class="result">
                    <h3>Email</h3>
                    <p class="result_summary">
                      The Email index contains messages from the archived Mailman mailing lists.
                    </p>
                  </div>
                </div> <!-- end search_result -->

                <div class="search_result">
                  <div class="result_icon genome_instrumentdata_flowcell_32">
                    <br/>
                  </div>
                  <div class="result">
                    <h3>Illumina Runs</h3>
                    <p class="result_summary">
                      A single run from the Illumina sequencer.
                    </p>
                  </div>
                </div> <!-- end search_result -->

                <div class="search_result">
                  <div class="result_icon genome_individual_32">
                    <br/>
                  </div>
                  <div class="result">
                    <h3>Individuals</h3>
                    <p class="result_summary">
                      Individuals are subjects whose samples are being sequenced and analyzed.
                    </p>
                  </div>
                </div> <!-- end search_result -->

                <div class="search_result">
                  <div class="result_icon genome_library_32">
                    <br/>
                  </div>
                  <div class="result">
                    <h3>Libraries</h3>
                    <p class="result_summary">
                      Libraries are samples that have been prepared for sequencing.
                    </p>
                  </div>
                </div> <!-- end search_result -->

                <div class="search_result">
                  <div class="result_icon genome_model_32">
                    <br/>
                  </div>
                  <div class="result">
                    <h3>Models</h3>
                    <p class="result_summary">
                      Models organize the history, analyzed data, and reports generated by the processing of instrument data from a sample or sample group.
                    </p>
                  </div>
                </div> <!-- end search_result -->

                <div class="search_result">
                  <div class="result_icon genome_modelgroup_32">
                    <br/>
                  </div>
                  <div class="result">
                    <h3>Model Groups</h3>
                    <p class="result_summary">
                      A group... of Models!
                    </p>
                  </div>
                </div> <!-- end search_result -->


              </div><!-- end .padding10 -->
            </div>
            <div style="width: 50%; float: right;">
              <div class="padding10">

                <div class="search_result">
                  <div class="result_icon genome_populationgroup_32">
                    <br/>
                  </div>
                  <div class="result">
                    <h3>Population Groups</h3>
                    <p class="result_summary">
                      Population Groups are subjects containing genetic material from more than one species.
                    </p>
                  </div>
                </div> <!-- end search_result -->

                <div class="search_result">
                  <div class="result_icon genome_processingprofile_32">
                    <br/>
                  </div>
                  <div class="result">
                    <h3>Processing Profiles</h3>
                    <p class="result_summary">
                      Processing profiles organize the set of software tools and parameters that a model uses to analyze it's data into a reusable package.
                    </p>
                  </div>
                </div> <!-- end search_result -->

                <div class="search_result">
                  <div class="result_icon genome_project_32">
                    <br/>
                  </div>
                  <div class="result">
                    <h3>Projects</h3>
                    <p class="result_summary">
                      A big bucket.
                    </p>
                  </div>
                </div> <!-- end search_result -->

                <div class="search_result">
                  <div class="result_icon genome_sample_32">
                    <br/>
                  </div>
                  <div class="result">
                    <h3>Samples</h3>
                    <p class="result_summary">
                      Samples are genetic material from collaborators that will be sequenced and anlayzed.
                    </p>
                  </div>
                </div> <!-- end search_result -->

                <div class="search_result">
                  <div class="result_icon genome_taxon_32">
                    <br/>
                  </div>
                  <div class="result">
                    <h3>Taxons</h3>
                    <p class="result_summary">
                      A Taxon is a group of (one or more) organisms, which a taxonomist adjudges to be a unit.
                    </p>
                  </div>
                </div> <!-- end search_result -->

                <div class="search_result">
                  <div class="result_icon genome_wiki_document_32">
                    <br/>
                  </div>
                  <div class="result">
                    <h3>Wiki Pages</h3>
                    <p class="result_summary">
                      Pages from the GC Wiki.
                    </p>
                  </div>
                </div> <!-- end search_result -->

                <div class="search_result">
                  <div class="result_icon genome_workorder_32">
                    <br/>
                  </div>
                  <div class="result">
                    <h3>Work Orders</h3>
                    <p class="result_summary">
                      Work Orders initiate, collect and record the progress of sample preparation and sequencing.
                    </p>
                  </div>
                </div> <!-- end search_result -->

              </div><!-- end .padding10 -->
            </div>
          </div> <!-- end .box_content -->
          <div class="box_content rounded span-24 last" style="margin: 0;">
            <div class="padding10">
              Please direct questions and comments regarding Analysis Search to the <a href="mailto:apipe@genome.wustl.edu">Analysis Pipeline</a> group.
            </div>
          </div>
        </div><!-- end .main_search_hints -->

      </div> <!-- end .container  -->
    </div> <!-- end .content  -->

    <xsl:call-template name="footer">
      <xsl:with-param name="footer_text">
        <br/>
      </xsl:with-param>
    </xsl:call-template>

  </xsl:template>

</xsl:stylesheet>
