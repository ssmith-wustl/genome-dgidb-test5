package Bio::SearchIO::cross_match;
use Bio::Search::Result::CrossMatchResult;
use Bio::SearchIO;
use Bio::Search::Hit::GenericHit;
use Bio::Search::HSP::GenericHSP;
our @ISA = qw(Bio::SearchIO);
=head2 next_result

 Title   : next_result
 Usage   : $result = stream->next_result
 Function: Reads the next ResultI object from the stream and returns it.

           Certain driver modules may encounter entries in the stream that
           are either misformatted or that use syntax not yet understood
           by the driver. If such an incident is recoverable, e.g., by
           dismissing a feature of a feature table or some other non-mandatory
           part of an entry, the driver will issue a warning. In the case
           of a non-recoverable situation an exception will be thrown.
           Do not assume that you can resume parsing the same stream after
           catching the exception. Note that you can always turn recoverable
           errors into exceptions by calling $stream->verbose(2) (see
           Bio::Root::RootI POD page).
 Returns : A Bio::Search::Result::ResultI object
 Args    : n/a

See L<Bio::Root::RootI>

=cut

sub next_result {
  my ($self) = @_;
  my $start = 0;
  while( defined ($_ = $self->_readline )) {
    return if($self->{'_end_document'});
    if(/^cross_match version\s+(.*?)$/) {
      $self->{_algorithm_version} = $1;
    } elsif(/^Maximal single base matches/) {
      $start = 1;
    } elsif(/^(\d+) matching entries/) {
      $self->{'_end_document'} = 1;
      return;
    } elsif(($start || $self->{'_result_count'}) && /^  (\d+)/) {
      $self->{'_result_count'} ++;
      return $self->_parse($_);
    } elsif(! $self->{_parameters}) {
      if(/.*?\s+(\-.*?)$/) {
        my $p = $1;
	my @pp = split /\s+/, $p;
	for(my $i = 0; $i < @pp; $i ++) {
	  if($pp[$i] =~ /^\-/) {
	    if($pp[$i + 1] && $pp[$i + 1] !~ /^\-/) {
	      $self->{_parameters}->{$pp[$i]} = $pp[$i + 1];
	      $i ++;
	    } else {
	      $self->{_parameters}->{$pp[$i]} = "";
	    }
	  }
	}
      }
    } elsif(/^Query file(s):\s+(.*?)$/) {
      $self->{_query_name} = $1;
    } elsif(/^Subject file(s):\s+(.*?)$/)  {
      $self->{_subject_name} = $2;
    }
  }
}
sub _alignment {
  my $self = shift;
=cut
C H_EO-aaa01PCR02    243 CCTCTGAATGGCTGAAGACCCCTCTGCCGAGGGAGGTTGGGGATTGTGGG 194
                                                                           
  0284119_008.c1-      1 CCTCTGAATGGCTGAAGACCCCTCTGCCGAGGGAGGTTGGGGATTGTGGG 50

C H_EO-aaa01PCR02    193 ACAAGGTCCCTTGGTGCTGATGGCCTGAAGGGGCCTGAGCTGTGGGCAGA 144
                                                                           
  0284119_008.c1-     51 ACAAGGTCCCTTGGTGCTGATGGCCTGAAGGGGCCTGAGCTGTGGGCAGA 100

C H_EO-aaa01PCR02    143 TGCAGTTTTCTGTGGGCTTGGGGAACCTCTCACGTTGCTGTGTCCTGGTG 94
                                                                           
  0284119_008.c1-    101 TGCAGTTTTCTGTGGGCTTGGGGAACCTCTCACGTTGCTGTGTCCTGGTG 150

C H_EO-aaa01PCR02     93 AGCAGCCCGACCAATAAACCTGCTTTTCTAAAAGGATCTGTGTTTGATTG 44
                                                                           
  0284119_008.c1-    151 AGCAGCCCGACCAATAAACCTGCTTTTCTAAAAGGATCTGTGTTTGATTG 200

C H_EO-aaa01PCR02     43 TATTCTCTGAAGGCAGTTACATAGGGTTACAGAGG 9
                                                            
  0284119_008.c1-    201 TATTCTCTGAAGGCAGTTACATAGGGTTACAGAGG 235
=cut
  #LSF: Should be the blank line. Otherwise error.
  my $blank = $self->_readline;
  unless($blank =~ /^\s*$/) {
    return;
  }
  my @data;
  my @pad;
  $count = 0;
  while( defined ($_ = $self->_readline )) {
    $count = 0 if($count >= 3);
    next if(/^$/);
    if(/^(C  \S+.*?\d+ )(\S+) \d+$|^(  \S+.*?\d+ )(\S+) \d+$$|^\s+$/) {
      $count ++;
      if($1 || $3) {
        $pad[$count] = $1 ? $1 : $3;
        push @{$data[$count]}, ($2 ? $2 : $4);
      } else {
        if(/\s{$pad[0],$pad[0]}(.*?)$/) {
	  push @{$data[$count]}, $1;
	} else {
          $self->throw("Format error for the homology line [$_].");	
	}
      }
    } else {
      last;
    }
  }
  return @data;
}
sub _parse {
  my $self = shift;
  my $line = shift;
  my $is_alignment = 0;
  my($hit_seq, $homology_seq, $query_seq);
#  32  5.13 0.00 0.00  H_DO-0065PCR0005792_034a.b1-1      327   365 (165)  C 1111547847_forward   (0)    39     1  
#OR
#ALIGNMENT   32  5.13 0.00 0.00  H_DO-0065PCR0005792_034a.b1-1      327   365 (165)  C 1111547847_forward   (0)    39     1  
  $line =~ s/^\s+|\s+$//g;
  my @r = split /\s+/, $line;
  if($r[0] eq "ALIGNMENT") {
    $is_alignment = 1;
    shift @r;
    ($hit_seq, $homology_seq, $query_seq) = $self->_alignment();
  }
  my $subject_seq_id;
  my $query_seq_id = $r[4];
  my $query_start = $r[5];
  my $query_end = $r[6];
  my $is_complement = 0;
  my $subject_start;
  my $subject_end;
  if($r[8] eq "C" && $r[9] !~ /^\(\d+\)$/) {
    $subject_seq_id = $r[9];
    $is_complement = 1;
    $subject_start = $r[11];
    $subject_end = $r[12];
  } else {
    $subject_seq_id = $r[8];
    $subject_start = $r[9];
    $subject_end = $r[10];
  }
  my $hit = new Bio::Search::Hit::GenericHit(-name => $subject_seq_id,
                                             -hsps => [new Bio::Search::HSP::GenericHSP(-query_name => $query_seq_id,
					                                               -query_start => $query_start,
										       -query_end => $query_end,
										       -hit_name => $subject_seq_id,
										       -hit_start => $subject_start,
										       -hit_end => $subject_end,
										       -query_length => 0,
										       -hit_length => 0,
										       -identical => $r[0],
										       -conserved => $r[0],
        									       -query_seq   => $query_seq ? (join "", @$query_seq) : "", #query sequence portion of the HSP
        									       -hit_seq     => $hit_seq ? (join "", @$hit_seq) : "",   #hit sequence portion of the HSP
        									       -homology_seq=> $homology_seq ? (join "", @$homology_seq) : "", #homology sequence for the HSP
										       #LSF: Need the direction, just to fool the GenericHSP module.
										       -algorithm => 'SW',)],
                                            );
  my $result = new Bio::Search::Result::CrossMatchResult( -query_name        => $self->{_query_name},
          -query_accession   => '',
          -query_description => '',
          -query_length      => 0,
          -database_name     => $self->{_subject_name},
          -database_letters  => 0,
          -database_entries  => 0,
          -parameters        => $self->{_parameters},
          -statistics        => {  },
          -algorithm         => 'cross_match',
          -algorithm_version => $self->{_algorithm_version},
          ); 
  $result->add_hit($hit); 
  return $result;
}

=head2 result_count

 Title   : result_count
 Usage   : $num = $stream->result_count;
 Function: Gets the number of Blast results that have been parsed.
 Returns : integer
 Args    : none
 Throws  : none

=cut

sub result_count {
  my $self = shift;
  return $self->{'_result_count'};
}

1;
#$Header$
