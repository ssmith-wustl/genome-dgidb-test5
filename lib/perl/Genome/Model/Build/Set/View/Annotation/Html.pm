package Genome::Model::Build::Set::View::Annotation::Html;

use strict;
use warnings;

use File::Basename;
use Data::Dumper;
use Genome;
use JSON;
use Sort::Naturally;
use Template;
use File::Temp qw/tempdir/;
use IO::File;
use Compress::Bzip2;

class Genome::Model::Build::Set::View::Annotation::Html {
    is => 'UR::Object::View::Default::Html',
    has_constant => [
        perspective => {
            value => 'annotation', # TODO nan desu ka?
        },
    ],
    has => [
        datatables_params => {
            is => 'String',
        },
        request_index => {
            is => 'String',
        },
        request_grep => {
            is => 'String',
        },
        request_grab => {
            is => 'String',
        },
        standard_build_id => {
            is => 'Number',
        },
        standard_build => {
            is => 'Genome::Model::Build',
            id_by => 'standard_build_id'
        }
    ],
};

#sub build_detail_html {
#    my ($self, @builds) = @_;
#
#    my $html = "<center><table class=\"build_detail\">\n";
#    $html .= "<tr><th colspan=\"4\">Build Detail</th></tr>\n";
#    $html .= "<tr><th>Id</th><th>Type</th><th>Model Id</th><th>Model Name</th></tr>\n";
#    for my $b (@builds) {
#        my $id= $b->id;
#        my $type = $b->type_name;
#        my $model_id = $b->model->id;
#        my $model_name = $b->model->name;
#        $model_name = substr($model_name, 0, 50)."..." if length($model_name) > 50;
#        $html .= "<tr><td>$id</td><td>$type</td><td>$model_id</td><td>$model_name</td></tr>\n";
#    }
#    $html .= "</table></center>\n";
#    return $html;
#}

#sub get_reference {
#    my $build = shift;
#    my @props = qw/reference_sequence_build reference/;
#    for my $p (@props) {
#        if ($build->model->can($p)) {
#            my $ref = $build->model->$p;
#            return $ref if $ref;
#        }
#    }
#    return;
#}

sub check_build {
    my $build = shift;
    my $name = $build->__display_name__;
#    if (!$build->can("snvs_bed") or !defined $build->snvs_bed("v2")) {
#        die "Failed to get snvs for build $name (snvs_bed missing or returned null)\n";
#    }
#
#    if (!$build->can("filtered_snvs_bed") or !defined $build->filtered_snvs_bed("v2")) {
#        die "Failed to get filtered snvs for build $name (filtered_snvs_bed missing or returned null)\n";
#    }
#
#    if (!get_reference($build)) {
#        die "Unable to determine reference sequence for build $name\n";
#    }
}

# maybe when running a sort build a line-based index, use perls sort to do a "slow" but memory efficient sort
# have a function that pulls a given field(s) from a line starting at a given fpos


sub get_lines {
    my ($self, %params) = @_;

    print "[32m".Data::Dumper::Dumper(\%params)."[0m\n";

    my %defaults = (
        offset => 0,
        limit => 500
    );
    
    for (keys %defaults) {
        # fill in defaults in params unless property is already specified
        $params{$_} = $defaults{$_} unless defined $params{$_};
    }

    my $file      = delete $params{file};
    my $offset    = delete $params{offset};
    my $limit     = delete $params{limit};
    my $delimiter = delete $params{delimiter};
    #my $index  = delete $params{index};  # use an index to limit to certain lines
    #my $query  = delete $params{query};  # what to query
    #my $sort   = delete $params{sort};   # what columns to sort by, + for asc, - for desc
    #my $filter = delete $params{filter}; # what columns to filter by

    die $self->error_message("No file or command specified to get lines from") unless defined $file;
    my $fh = IO::File->new("$file") || die $self->error_message("Can't pipe command '$file'.");
    
    my @lines;

    my $count = 0;
    
    # TODO more robust interface
    # TODO test limits and offsets
    while (my $line = <$fh>) {
        if ( ($count >= $offset) && (scalar(@lines) < $limit) ) {
            if (defined ($delimiter)) {
                push @lines, [split($delimiter, $line)];
            } else {
                push @lines, [$line];
            }
        }
        $count++;
    }

    $fh->close();
    
    my %rv = (
        lines_read => $count,
        lines => \@lines
    );
     
    return \%rv;
}

# not currently used; could merge with build_gene_index to make something more general-purpose
# TODO the index could then be used to sort a given field of a huge file in a memory efficient way
#sub build_line_index {
#    my $self = shift;
#    my $file = shift;
#    my $column = shift;
#    my $delim = shift;
#
#    my $fh = IO::File->new($file) || die $self->error_message("Can't open file '$file'.");
#
#    if (defined($column) and defined($delim)) { # a bit slower
#        my @index;
#        my $pos = 0;
#
#        while (my $line = <$fh>) {
#            my $offset = 0;
#            for (my $i = 0; $i < $column; $i++) {
#                $offset = 1+index($line, $delim, $offset);
#            }
#            my $end = index($line, $delim, $offset);
#            
#            $end += $end == -1 ? tell($fh) : $pos;
#            push @index, [$pos+$offset, $end];
#            
#            $pos = tell($fh);
#        }
#        
#        return \@index;
#    } else { # go fast
#        my @index;
#
#        do {
#            push @index, tell($fh);
#        } while (<$fh>);
#        
#        pop @index; # the last value will be bogus
#
#        return \@index;
#    }
#}

sub build_gene_index {
    my $self = shift;
    my $file = shift;

    my $fh = IO::File->new($file) || die $self->error_message("Can't open $file.");

    my %hash;

    my $cur_gene;
    my $cur_gene_pos;
    
    my $pos = 0;
    
    while (my $line = <$fh>) {
        # get the byte pos of the 7th field without using split:
        my $index = 1+index($line, "\t", 1+index($line, "\t", 1+index(
            $line, "\t", 1+index($line, "\t", 1+index($line, "\t", 1+index($line, "\t"))))));

        # get the byte pos of the end of the 7th field
        my $end = index($line, "\t", $index);

        my $gene = substr($line, $index, $end - $index);
        if (uc $gene ne $cur_gene) { # if genes differ
            if (defined($cur_gene)) { # and there's a previous gene
                if (defined($hash{$cur_gene})) { # this distinciton may be unecessary...
                    push @{$hash{$cur_gene}}, [$cur_gene_pos, $pos];
                } else {
                    $hash{$cur_gene} = [
                        [$cur_gene_pos, $pos]
                    ];
                }
            }

            $cur_gene = uc $gene;
            $cur_gene_pos = $pos;
        }
        #$pos = $fh->tell();
        $pos = tell($fh);
    }

    # add the last gene
    if (defined($cur_gene)) {
        if (defined($hash{$cur_gene})) { # this distinciton may be unecessary...
            push @{$hash{$cur_gene}}, [$cur_gene_pos, $pos];
        } else {
            $hash{$cur_gene} = [
                [$cur_gene_pos, $pos]
            ];
        }
    }
    
    $fh->close();
    
    return \%hash;
}

### END TODO

sub get_lines_via_gene_index {
    my $self = shift;
    my $file = shift;
    my $bands = shift;
    my $offset = shift;
    my $limit = shift;

    print "[36m;".Data::Dumper::Dumper($bands)."[0m\n";

    my $fh = IO::File->new($file) || die $self->error_message("Can't open $file.");
    
    my @lines;
    
    my $count = 0;
    if ($limit == -1) { $limit = 500; }
    
    # TODO more robust interface
    # TODO test limits and offsets
    # TODO may want to explicitly sort bands, but they should be in the order of earlier first...
    for my $band (@{$bands}) {
        my $start = $band->[0];
        my $end = $band->[1];
        seek($fh, $start, 0);
        while (tell($fh) != $end) {
            my $line = $fh->getline();
            if ( ($count >= $offset) && (scalar(@lines) < $limit) ) {
                push @lines, [split("\t", $line)];
            }
            $count++;
            die $self->error_message("Seeked too far.") if (tell($fh) > $end);
        }
    }

    $fh->close();
    
    my %rv = (
        lines_read => $count,
        lines => \@lines
    );
     
    return \%rv;
}

sub _generate_content {
    my $self = shift;
    
    my $annotations_file = "/gscuser/iferguso/annotation_view/annotations20000.txt";
    #my $annotations_file = "/gscuser/iferguso/annotation_view/filtered.variants.post_annotation";

    my @builds = $self->subject->members;
    if (@builds != 1) {
        return $self->_format_error(sprintf("Error: expected one (and only one) build id.  I got %s ids.", scalar @builds));
    }
    
    if (!$self->standard_build) {
        return $self->_format_error("Error: expected a standard build id but did not get one.");
    }

    my $subject_build = $builds[0];
    
    unshift(@builds, $self->standard_build);
    for my $b (@builds) {
        eval { check_build($b); };
        if ($@) {
            return $self->_format_error($@);
        }
    }

    #if (!get_reference($self->standard_build)->is_compatible_with(get_reference($subject_build))) {
    #    my $b1name = $self->standard_build->__display_name__;
    #    my $b2name = $subject_build->__display_name__;
    #    my $r1name = get_reference($self->standard_build)->name;
    #    my $r2name = get_reference($subject_build)->name;
    #    return $self->_format_error("Incompatible reference sequences for builds:\n '$b1name' uses $r1name\n'$b2name' uses $r2name");
    #}

    #my %filter_methods = (
    #    filtered => "filtered_snvs_bed",
    #    unfiltered => "snvs_bed"
    #);
    #my @unfiltered_files = map {$_->snvs_bed("v1")} @builds;
    #my @filtered_files = map {$_->filtered_snvs_bed("v1")} @builds;
    #my @names = map {$_->id} @builds;
    #my $title = "Snv Intersection for builds: " . join(", ", @names);

    #my $report = $self->build_detail_html(@builds);
    #for my $filt ( keys %filter_methods ) {
    #    my $fn = $filter_methods{$filt};
    #    my @files = map { $_->$fn("v1") } @builds;
    #    my $tmpdir = tempdir(CLEANUP => 1);
    #    my $tmpfile = "$tmpdir/snv_concordance.out";
    #    my $cmd = Genome::Model::Tools::Joinx::SnvConcordance->create(
    #        input_file_a => $files[0],
    #        input_file_b => $files[1],
    #        output_file => $tmpfile,
    #        depth => 1,
    #    );
    #    eval { $cmd->execute; };
    #    if ($@) { return $self->_format_error($@); }
    #    my $results = Genome::Model::Tools::Joinx::SnvConcordance::parse_results_file($tmpfile);

    #    my @errs = $cmd->__errors__;
    #    if (@errs) {
    #        return $self->_format_error(join ("\n", map{$_->__display_name__} @errs));
    #    }
    #    $report .= format_results_html($results, ucfirst($filt)." SNVs");
    #}
    
    my $cache = Genome::Memcache->server();

    if (defined($self->datatables_params())) {
        my $dtparams;
        my @params = split(",",$self->datatables_params());
        while (scalar(@params)) {
            my ($key, $value) = (shift(@params), shift(@params));
            $dtparams->{$key} = $value;
        }
        print "[35m". Data::Dumper::Dumper($dtparams)."[0m\n";

        my $offset = $dtparams->{'iDisplayStart'};
        my $limit = $dtparams->{'iDisplayLength'};
        my $sEcho = $dtparams->{'sEcho'};
        my $sSearch = $dtparams->{'sSearch'};
        my $sSearchType = $dtparams->{'sSearchType'};
        
        my $key = sprintf("%s-%s-%s", "Genome::Model::Build::Set::View::Annotation::Html", "build-id", $subject_build->id());

        if (!$sSearch) {
            # TODO should return the default view
            my $lines = $self->get_lines(
                file => $annotations_file,
                offset => $offset,
                limit => $limit,
                delimiter => "\t"
            );
            return $self->datatables_response($lines->{lines}, $lines->{lines_read}, $lines->{lines_read}, $sEcho);

        } elsif ($sSearchType eq 'gene') {
            if ($cache && (my $compressed_str = $cache->get($key))) {
                my $value = from_json(Compress::Bzip2::decompress($compressed_str), {ascii => 1});

                my $index = $value->{'index'};
                
                if (defined($index->{$sSearch})) {
                    my $lines = $self->get_lines_via_gene_index($annotations_file, $index->{$sSearch}, $offset, $limit);
                    print "[23m".$value->{'line_count'}."[0m\n";
                    return $self->datatables_response($lines->{lines}, $lines->{lines_read}, $value->{'line_count'}, $sEcho);
                } else {
                    return $self->datatables_response([], 0, $value->{'line_count'}, $sEcho);
                }
            } else {
                my $lines = $self->get_lines(
                    file => "awk -F \"\\t\" '{ if (\$7 == '$sSearch') print \$0 }' $annotations_file | ",
                    offset => $offset,
                    limit => $limit,
                    delimiter => "\t"
                );
                return $self->datatables_response($lines->{lines}, $lines->{lines_read}, 0, $sEcho);
            }
        } elsif ($sSearchType eq 'grep') { # full text grep
            my $escaped_search = $sSearch;
            $escaped_search =~ s/'/'"'"'/g; # disgusting
            $escaped_search = "'$escaped_search'";
            my $lines = $self->get_lines(
                file => "grep $escaped_search $annotations_file | ",
                offset => $offset,
                limit => $limit,
                delimiter => "\t"
            );

            my $lines_count = 0;
            # get lines read from memcache if we can
            if ($cache && (my $compressed_str = $cache->get($key))) {
                my $value = from_json(Compress::Bzip2::decompress($compressed_str), {ascii => 1});
                $lines_count = $value->{line_count};
            }

            return $self->datatables_response($lines->{lines}, $lines->{lines_read}, $lines_count, $sEcho);
        }
    } elsif (defined($self->request_index())) {
        my $key = sprintf("%s-%s-%s", "Genome::Model::Build::Set::View::Annotation::Html", "build-id", $subject_build->id());

        my $requested = $self->request_index() > 0 ? 1 : 0;
        my $exists = defined($cache->get($key)) ? 1 : 0;
        my $force = $self->request_index() eq '2' ? 1 : 0;
        my $should_build = $cache && $requested && ($force || !$exists) ? 1 : 0;
        
        if ($should_build) {
            print "[32mBuilding cache with key '$key'[0m\n";

            my @wc = split(/\s+/,`wc -l $annotations_file`);
            my $index = $self->build_gene_index($annotations_file);

            my $data = {
                index => $index,
                line_count => $wc[0],
            };
            
            $cache->set($key, Compress::Bzip2::compress(to_json($data, {ascii => 1})), 600);
        }
        
        return to_json({requested => $requested, built => $should_build, existed => $exists, forced => $force}, {ascii => 1});
    } else {
        # this will eventually dumpout test.html with ids and line count filled in and a minimal set of lines at the head
        my @wc = split(/\s+/,`wc -l $annotations_file`);
        return "<p>lines: $wc[0]</p>";
    }
    
}

#sub format_results_html {
#    my ($results, $title) = @_;
#
#    my $html = "<div class=\"section_content\">\n";
#    $html .= "<h2 class=\"section_title\">$title</h2><br>\n";
#    $html .= "<div style=\"padding-left: 10px;\">\n";
#    $html .= "<table class=\"snv\">\n";
#    for my $a_type (keys %$results) {
#        next if scalar keys %{$results->{$a_type}{hits}} == 0;
#        my $total = $results->{$a_type}{total}; 
#        my $uc_a_type = join(" ", map { ucfirst($_) } split(" ", $a_type));
#        $html .= "<tr><td class=\"snv_category_head\">$uc_a_type</td>\n";
#        $html .= "<td class=\"snv_category_head\" colspan=\"3\">$total</td></tr>\n";
#        $html .= "<tr class=\"snv_category_flds\">\n";
#        $html .= "<th>&nbsp;</td>\n";
#        $html .= "<th>SNVs</td>\n";
#        $html .= "<th>%</td>\n";
#        $html .= "<th>Avg Depth</td>\n";
#        $html .= "</tr>\n";
#        for my $match_type (keys %{$results->{$a_type}{hits}}) {
#            my $uc_match_type = join(" ", map { ucfirst($_) } split(" ", $match_type));
#            $html .= "<tr><td class=\"match_type\" colspan=\"4\">$uc_match_type</td></tr>\n";
#            for my $b_type (keys %{$results->{$a_type}{hits}{$match_type}}) {
#                $html .= "<tr>\n";
#                my $count = $results->{$a_type}{hits}{$match_type}{$b_type}{count};
#                my $qual  = $results->{$a_type}{hits}{$match_type}{$b_type}{qual};
#                my $percent = sprintf "%.02f", 100*$count / $total; 
#                $html .= "<td class=\"hit_detail\">$b_type</td>\n";
#                $html .= "<td class=\"hit_detail\">$count</td>\n";
#                $html .= "<td class=\"hit_detail\">$percent</td>\n";
#                $html .= "<td class=\"hit_detail\">$qual</td>\n";
#                $html .= "</tr>\n";
#            }
#        }
#    }
#    $html .= "</table></div></div>\n";
#     
#    return $html;
#}

sub _format_error {
    my ($self, $message) = @_;
    $message = "<div class=\"error\"><pre>$message</pre></div>";
    return $self->_render_view("Error", $message);
}

sub _get_results {
    my ($self, $build) = @_;
}

sub _base_path_for_templates {
    my $module = __PACKAGE__;
    $module =~ s/::/\//g;
    $module .= '.pm';
    my $module_path = $INC{$module};
    unless ($module_path) {
        die "Module " . __PACKAGE__ . " failed to find its own path!  Checked for $module in \%INC...";
    }
    return dirname($module_path);
}

sub _support_file_path {
    my ($self, $file) = @_;
    return $self->_base_path_for_templates . "/$file";
}

sub _hashref_to_json_array {
    my ($h) = @_;

    my @arr = map { [$_, $h->{$_}] } sort {$a <=> $b} keys %$h;

    return to_json(\@arr, {ascii => 1});
}

sub datatables_response {
    my ($self, $lines, $filtered_lines, $total_lines, $sEcho) = @_;

    my $rv = {
        "sEcho" => $sEcho,
        "iTotalRecords" => $total_lines,
        "iTotalDisplayRecords" => $filtered_lines,
        "aaData" => $lines
    };

    return to_json($rv, {ascii => 1});
}

sub lines_as_table {
    my ($self, $lines) = @_;

    my @vars = (
        lines => $lines
    );

    my $template = $self->_support_file_path("Table.html.tt2");
    my $tt = Template->new({ ABSOLUTE => 1 }) || die "$Template::ERROR\n";

    $self->status_message("processing template $template");

    my $content;
    my $rv = $tt->process($template, { @vars }, \$content) || die $tt->error(), "\n";
    if ($rv != 1) {
   	    die "Bad return value from template processing for summary report generation: $rv ";
    }
    unless ($content) {
        die "No content returned from template processing!";
    }
    return $content;
}

sub _render_view {
    my ($self, $title, $report_html, $lines) = @_;
    print Data::Dumper::Dumper($lines);

    ## get CSS resources
    my $css_file = $self->_support_file_path("Annotation.css");
    my $css_fh = IO::File->new($css_file);
    unless ($css_fh) {
        die "failed to open file $css_file!"; 
    }
    my $page_css = join('',$css_fh->getlines);

    my @vars = (
        page_title => $title,
        style => $page_css,
        report_content => $report_html,
        lines => $lines
    );

    my $template = $self->_support_file_path("Annotation.html.tt2");
    my $tt = Template->new({ ABSOLUTE => 1 }) || die "$Template::ERROR\n";

    $self->status_message("processing template $template");

    my $content;
    my $rv = $tt->process($template, { @vars }, \$content) || die $tt->error(), "\n";
    if ($rv != 1) {
   	    die "Bad return value from template processing for summary report generation: $rv ";
    }
    unless ($content) {
        die "No content returned from template processing!";
    }
    return $content;
}

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}

1;
