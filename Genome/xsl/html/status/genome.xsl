<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">

  <xsl:template match="/search-form">

    <script type="text/javascript">
      (function($) {
        $("div.page_padding").css("padding","0px");
        $("div.background,div.container").width(670);
      })(jQuery);
    </script>
    <div class="search_form_container">
      <div class="search_form">
        <form method="get" action="/view/genome/search/query/status.html">
          <table cellspacing="0" cellpadding="0" border="0" class="form">
            <tr>
              <td style="white-space: nowrap; font-weight: bold;">
                GC Search:
              </td>
              <td>
                <input type="text" size="30" name="query" style="background-color: #FFF; font-size: 120%;"/><br/>
              </td>
              <td>
                <input type="submit" value="Search"/>
              </td>
            </tr>
          </table>
        </form>
      </div>
      <div class="search_help">
        <p></p>
      </div>
    </div>
    <div class="page_padding">
      <br/>
      <br/>
      <h2 class="form_group" style="padding-top: 15px;">Search for Models and Builds</h2>
      <form action="/view/genome/model/set/status.html" method="GET">
        <table cellpadding="0" cellspacing="0" border="0" class="form" width="100%">
          <colgroup>
            <col width="25%"/>
            <col width="30%"/>
            <col width="100%"/>
          </colgroup>
          <tbody>
            <tr>
              <td class="label">Model Name:</td>
              <td class="input">
                <input type="text" name="name LIKE" value="" />
              </td>
              <td>
                <input type="submit" name="_submit" value="Search for Model Name" />
              </td>
            </tr>
          </tbody>
        </table>
      </form>
      <form action="/view/genome/model/status.html" method="GET">
        <table cellpadding="0" cellspacing="0" border="0" class="form" width="100%">
          <colgroup>
            <col width="25%"/>
            <col width="30%"/>
            <col width="100%"/>
          </colgroup>
          <tbody>
            <tr>
              <td class="label">Model ID:</td>
              <td class="input">
                <input type="text" name="id" value="" />
              </td>
              <td>
                <input type="submit" name="_submit" value="Search for Model ID" />
              </td>
            </tr>
          </tbody>
        </table>
      </form>
      <form action="/view/genome/model/set/status.html" method="GET">
        <table cellpadding="0" cellspacing="0" border="0" class="form" width="100%">
          <colgroup>
            <col width="25%"/>
            <col width="30%"/>
            <col width="100%"/>
          </colgroup>
          <tbody>
            <tr>
              <td class="label">Models Owned by User:</td>
              <td class="input">
                <select name="user_name">
                  <option value="" selected="selected">Select a User</option>
                  <xsl:for-each select="//users/user">
                    <option><xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute><xsl:value-of select="."/></option>
                  </xsl:for-each>
                </select>
              </td>
              <td>
                <input type="submit" value="Search for Models" />
              </td>
            </tr>
          </tbody>
        </table>
      </form>
      <form action="/view/genome/model/build/status.html" method="GET">
        <table cellpadding="0" cellspacing="0" border="0" class="form" width="100%">
          <colgroup>
            <col width="25%"/>
            <col width="30%"/>
            <col width="100%"/>
          </colgroup>
          <tbody>
            <tr>
              <td class="label">Build ID:</td>
              <td class="input">
                <input type="text" name="id" value="" />
              </td>
              <td>
                <input type="submit" value="Search for Build ID" />
              </td>
            </tr>
          </tbody>
        </table>
      </form>
      <form action="/view/genome/model/build/set/status.html" method="GET">
        <table cellpadding="0" cellspacing="0" border="0" class="form" width="100%">
          <colgroup>
            <col width="25%"/>
            <col width="30%"/>
            <col width="100%"/>
          </colgroup>
          <tbody>
            <tr>
              <td class="label">Builds with Status:</td>
              <td class="input">
                <select name="master_event_status">
                  <option value="" selected="selected">Select a Status</option>
                  <xsl:for-each select="//event-statuses/event-status">
                    <option><xsl:attribute name="value"><xsl:value-of select="."/></xsl:attribute><xsl:value-of select="."/></option>
                  </xsl:for-each>
                </select>
              </td>
              <td>
                <input type="submit" value="Search for Builds" />
              </td>
            </tr>
          </tbody>
        </table>
      </form>
      <h2 class="form_group">Compare Model GoldSNP Metrics</h2>
      <form action="/view/genome/model/set/gold-snp-comparison.html" method="GET">
        <table cellpadding="0" cellspacing="0" border="0" class="form" width="100%">
          <colgroup>
            <col width="25%"/>
            <col width="30%"/>
            <col width="100%"/>
          </colgroup>
          <tbody>
            <tr>
              <td class="label">Model ID 1:</td>
              <td class="input">
                <input type="text" name="genome_model_id" />
              </td>
              <td>

              </td>
            </tr>
            <tr>
              <td class="label">Model ID 2:</td>
              <td class="input">
                <input type="text" name="genome_model_id" />
              </td>
              <td>

              </td>
            </tr>
            <tr>
              <td class="label">Model ID 3:</td>
              <td class="input">
                <input type="text" name="genome_model_id" value="" />
              </td>
              <td>

              </td>
            </tr>
            <tr>
              <td class="label">Model ID 4:</td>
              <td class="input">
                <input type="text" name="genome_model_id" value="" />
              </td>
              <td>

              </td>
            </tr>
            <tr>
              <td class="label">Model ID 5:</td>
              <td class="input">
                <input type="text" name="genome_model_id" value="" />
              </td>
              <td>

              </td>
            </tr>
            <tr>
              <td class="label"></td>
              <td class="input">

              </td>
              <td>
                <input type="submit" value="Compare Models" />
              </td>
            </tr>
          </tbody>
        </table>
      </form>
    </div>

  </xsl:template>

</xsl:stylesheet>
