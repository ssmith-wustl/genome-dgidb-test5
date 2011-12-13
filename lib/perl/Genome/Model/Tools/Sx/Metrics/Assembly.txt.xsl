<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
  <xsl:output method="text"/>
  <xsl:output doctype-system="http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"/>
  <xsl:output doctype-public="-//W3C//DTD XHTML 1.0 Transitional//EN"/>
  <xsl:template match="/">*** SIMPLE READ STATS ***
Total input reads: <xsl:value-of select="//aspect[@name='reads_count']/value"/>
Total input bases: <xsl:value-of select="//aspect[@name='reads_length']/value"/> bp
Total Q20 bases: <xsl:value-of select="//aspect[@name='reads_length_q20']/value"/> bp
Average Q20 bases per read: <xsl:value-of select="//aspect[@name='reads_length_q20_per_read']/value"/> bp
Average read length: <xsl:value-of select="//aspect[@name='reads_average_length']/value"/> bp
Placed reads: <xsl:value-of select="//aspect[@name='reads_placed']/value"/>
(reads in scaffolds: <xsl:value-of select="//aspect[@name='reads_placed_in_scaffolds']/value"/>)
(unique reads: <xsl:value-of select="//aspect[@name='reads_placed_unique']/value"/>)
(duplicate reads: <xsl:value-of select="//aspect[@name='reads_placed_duplicate']/value"/>)
Unplaced reads: <xsl:value-of select="//aspect[@name='reads_unplaced']/value"/>
Chaff rate: <xsl:value-of select="//aspect[@name='reads_chaff_rate']/value"/>
Q20 base redundancy: <xsl:value-of select="//aspect[@name='reads_length_q20_redundancy']/value"/>


*** Contiguity: Contig ***
Total Contig number: <xsl:value-of select="//aspect[@name='contigs_count']/value"/>
Total Contig bases: <xsl:value-of select="//aspect[@name='contigs_length']/value"/> bp
Total Q20 bases: <xsl:value-of select="//aspect[@name='contigs_length_q20']/value"/> bp
Q20 bases %: <xsl:value-of select="//aspect[@name='contigs_length_q20_percent']/value"/> %
Average Contig length: <xsl:value-of select="//aspect[@name='contigs_average_length']/value"/> bp
Maximum Contig length: <xsl:value-of select="//aspect[@name='contigs_maximum_length']/value"/> bp
N50 Contig length: <xsl:value-of select="//aspect[@name='contigs_n50_length']/value"/> bp
N50 contig number: <xsl:value-of select="//aspect[@name='contigs_n50_count']/value"/>

Major Contig (> <xsl:value-of select="//aspect[@name='major_contig_threshold']/value"/> bp) number: <xsl:value-of select="//aspect[@name='contigs_major_count']/value"/>
Major Contig bases: <xsl:value-of select="//aspect[@name='contigs_major_length']/value"/> bp
Major_Contig avg contig length: <xsl:value-of select="//aspect[@name='contigs_major_average_length']/value"/> bp
Major_Contig Q20 bases: <xsl:value-of select="//aspect[@name='contigs_major_length_q20']/value"/> bp
Major_Contig Q20 base percent: <xsl:value-of select="//aspect[@name='contigs_major_length_q20_percent']/value"/> %
Major_Contig N50 contig length: <xsl:value-of select="//aspect[@name='contigs_major_n50_length']/value"/> bp
Major_Contig N50 contig number: <xsl:value-of select="//aspect[@name='contigs_major_n50_count']/value"/>

Top tier (up to <xsl:value-of select="//aspect[@name='tier_one']/value"/> bp): 
  Contig number: <xsl:value-of select="//aspect[@name='contigs_t1_count']/value"/>
  Average length: <xsl:value-of select="//aspect[@name='contigs_t1_average_length']/value"/> bp
  Longest length: <xsl:value-of select="//aspect[@name='contigs_t1_maximum_length']/value"/> bp
  Contig bases in this tier: <xsl:value-of select="//aspect[@name='contigs_t1_length']/value"/> bp
  Q20 bases in this tier: <xsl:value-of select="//aspect[@name='contigs_t1_length_q20']/value"/> bp
  Q20 base percentage: <xsl:value-of select="//aspect[@name='contigs_t1_length_q20_percent']/value"/> %
  Top tier N50 contig length: <xsl:value-of select="//aspect[@name='contigs_t1_n50_length']/value"/> bp
  Top tier N50 contig number: <xsl:value-of select="//aspect[@name='contigs_t1_n50_count']/value"/>
Middle tier (<xsl:value-of select="//aspect[@name='tier_one']/value"/> bp -- <xsl:value-of select="//aspect[@name='tier_two']/value"/> bp): 
  Contig number: <xsl:value-of select="//aspect[@name='contigs_t2_count']/value"/>
  Average length: <xsl:value-of select="//aspect[@name='contigs_t2_average_length']/value"/> bp
  Longest length: <xsl:value-of select="//aspect[@name='contigs_t2_maximum_length']/value"/> bp
  Contig bases in this tier: <xsl:value-of select="//aspect[@name='contigs_t2_length']/value"/> bp
  Q20 bases in this tier: <xsl:value-of select="//aspect[@name='contigs_t2_length_q20']/value"/> bp
  Q20 base percentage: <xsl:value-of select="//aspect[@name='contigs_t2_length_q20_percent']/value"/> %
  Middle tier N50 contig length: <xsl:value-of select="//aspect[@name='contigs_t2_n50_length']/value"/> bp
  Middle tier N50 contig number: <xsl:value-of select="//aspect[@name='contigs_t2_n50_count']/value"/>
Bottom tier (<xsl:value-of select="//aspect[@name='tier_two']/value"/> bp -- end): 
  Contig number: <xsl:value-of select="//aspect[@name='contigs_t3_count']/value"/>
  Average length: <xsl:value-of select="//aspect[@name='contigs_t3_average_length']/value"/> bp
  Longest length: <xsl:value-of select="//aspect[@name='contigs_t3_maximum_length']/value"/> bp
  Contig bases in this tier: <xsl:value-of select="//aspect[@name='contigs_t3_length']/value"/> bp
  Q20 bases in this tier: <xsl:value-of select="//aspect[@name='contigs_t3_length_q20']/value"/> bp
  Q20 base percentage: <xsl:value-of select="//aspect[@name='contigs_t3_length_q20_percent']/value"/> %
  Bottom tier N50 contig length: <xsl:value-of select="//aspect[@name='contigs_t3_n50_length']/value"/> bp
  Bottom tier N50 contig number: <xsl:value-of select="//aspect[@name='contigs_t3_n50_count']/value"/>


*** Contiguity: Supercontig ***
Total Supercontig number: <xsl:value-of select="//aspect[@name='supercontigs_count']/value"/>
Total Supercontig bases: <xsl:value-of select="//aspect[@name='supercontigs_length']/value"/> bp
Total Q20 bases: <xsl:value-of select="//aspect[@name='supercontigs_length_q20']/value"/> bp
Q20 bases %: <xsl:value-of select="//aspect[@name='supercontigs_length_q20_percent']/value"/> %
Average Supercontig length: <xsl:value-of select="//aspect[@name='supercontigs_average_length']/value"/> bp
Maximum Supercontig length: <xsl:value-of select="//aspect[@name='supercontigs_maximum_length']/value"/> bp
N50 Supercontig length: <xsl:value-of select="//aspect[@name='supercontigs_n50_length']/value"/> bp
N50 contig number: <xsl:value-of select="//aspect[@name='supercontigs_n50_count']/value"/>

Major Supercontig (> <xsl:value-of select="//aspect[@name='major_contig_threshold']/value"/> bp) number: <xsl:value-of select="//aspect[@name='supercontigs_major_count']/value"/>
Major Supercontig bases: <xsl:value-of select="//aspect[@name='supercontigs_major_length']/value"/> bp
Major_Supercontig avg contig length: <xsl:value-of select="//aspect[@name='supercontigs_major_average_length']/value"/> bp
Major_Supercontig Q20 bases: <xsl:value-of select="//aspect[@name='supercontigs_major_length_q20']/value"/> bp
Major_Supercontig Q20 base percent: <xsl:value-of select="//aspect[@name='supercontigs_major_length_q20_percent']/value"/> %
Major_Supercontig N50 contig length: <xsl:value-of select="//aspect[@name='supercontigs_major_n50_length']/value"/> bp
Major_Supercontig N50 contig number: <xsl:value-of select="//aspect[@name='supercontigs_major_n50_count']/value"/>

Scaffolds > 1M: <xsl:value-of select="//aspect[@name='scaffolds_1M']/value"/>
Scaffold 250K--1M: <xsl:value-of select="//aspect[@name='scaffolds_250K_1M']/value"/>
Scaffold 100K--250K: <xsl:value-of select="//aspect[@name='scaffolds_100K_250K']/value"/>
Scaffold 10--100K: <xsl:value-of select="//aspect[@name='scaffolds_10K_100K']/value"/>
Scaffold 5--10K: <xsl:value-of select="//aspect[@name='scaffolds_5K_10K']/value"/>
Scaffold 2--5K: <xsl:value-of select="//aspect[@name='scaffolds_2K_5K']/value"/>
Scaffold 0--2K: <xsl:value-of select="//aspect[@name='scaffolds_0K_2K']/value"/>

Top tier (up to <xsl:value-of select="//aspect[@name='tier_one']/value"/> bp): 
  Contig number: <xsl:value-of select="//aspect[@name='supercontigs_t1_count']/value"/>
  Average length: <xsl:value-of select="//aspect[@name='supercontigs_t1_average_length']/value"/> bp
  Longest length: <xsl:value-of select="//aspect[@name='supercontigs_t1_maximum_length']/value"/> bp
  Contig bases in this tier: <xsl:value-of select="//aspect[@name='supercontigs_t1_length']/value"/> bp
  Q20 bases in this tier: <xsl:value-of select="//aspect[@name='supercontigs_t1_length_q20']/value"/> bp
  Q20 base percentage: <xsl:value-of select="//aspect[@name='supercontigs_t1_length_q20_percent']/value"/> %
  Top tier N50 contig length: <xsl:value-of select="//aspect[@name='supercontigs_t1_n50_length']/value"/> bp
  Top tier N50 contig number: <xsl:value-of select="//aspect[@name='supercontigs_t1_n50_count']/value"/>
Middle tier (<xsl:value-of select="//aspect[@name='tier_one']/value"/> bp -- <xsl:value-of select="//aspect[@name='tier_two']/value"/> bp): 
  Contig number: <xsl:value-of select="//aspect[@name='supercontigs_t2_count']/value"/>
  Average length: <xsl:value-of select="//aspect[@name='supercontigs_t2_average_length']/value"/> bp
  Longest length: <xsl:value-of select="//aspect[@name='supercontigs_t2_maximum_length']/value"/> bp
  Contig bases in this tier: <xsl:value-of select="//aspect[@name='supercontigs_t2_length']/value"/> bp
  Q20 bases in this tier: <xsl:value-of select="//aspect[@name='supercontigs_t2_length_q20']/value"/> bp
  Q20 base percentage: <xsl:value-of select="//aspect[@name='supercontigs_t2_length_q20_percent']/value"/> %
  Middle tier N50 contig length: <xsl:value-of select="//aspect[@name='supercontigs_t2_n50_length']/value"/> bp
  Middle tier N50 contig number: <xsl:value-of select="//aspect[@name='supercontigs_t2_n50_count']/value"/>
Bottom tier (<xsl:value-of select="//aspect[@name='tier_two']/value"/> bp -- end): 
  Contig number: <xsl:value-of select="//aspect[@name='supercontigs_t3_count']/value"/>
  Average length: <xsl:value-of select="//aspect[@name='supercontigs_t3_average_length']/value"/> bp
  Longest length: <xsl:value-of select="//aspect[@name='supercontigs_t3_maximum_length']/value"/> bp
  Contig bases in this tier: <xsl:value-of select="//aspect[@name='supercontigs_t3_length']/value"/> bp
  Q20 bases in this tier: <xsl:value-of select="//aspect[@name='supercontigs_t3_length_q20']/value"/> bp
  Q20 base percentage: <xsl:value-of select="//aspect[@name='supercontigs_t3_length_q20_percent']/value"/> %
  Bottom tier N50 contig length: <xsl:value-of select="//aspect[@name='supercontigs_t3_n50_length']/value"/> bp
  Bottom tier N50 contig number: <xsl:value-of select="//aspect[@name='supercontigs_t3_n50_count']/value"/>
  <xsl:text>&#10;</xsl:text>
  <xsl:text>&#10;</xsl:text>
  </xsl:template>
</xsl:stylesheet>
