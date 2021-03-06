package LJ::Widget::ManageSiteMessages;

use strict;
use base qw(LJ::Widget);
use Carp qw(croak);
use Class::Autouse qw( LJ::SiteMessages );

sub need_res { }

sub render_body {
    my $class = shift;
    my %opts = @_;

    my $get = delete $opts{get};

    my $ret = "";

    # default values for year/month
    my $year  = $get->{year}+0;
    my $month = $get->{month}+0;

    # if year and month aren't defined, use the current month
    unless ($year && $month) {
        my @time = localtime();
        $year  = $time[5]+1900;
        $month = $time[4]+1;
    }
    
    $ret .= "<div class='b-adminpage b-adminpage-padding'>";
    $ret .= "<?p (<a href='$LJ::SITEROOT/admin/sitemessages/add.bml'>Add a site message</a>) p?>";
    $ret .= "<?p Select a month to view all messages that started during that month. p?>";

    # TODO: supported way for widgets to do GET forms?
    #       -- lame that GET/POST is done differently in here
    $ret .= "<form method='GET'>";
    $ret .= "<?p Year: " . LJ::html_text({ name => 'year', size => '4', maxlength => '4', value => $year }) . " ";
    $ret .= "Month: " . LJ::html_select({ name => 'month', selected => $month }, map { $_, LJ::Lang::month_long($_) } 1..12) . " p?>";
    $ret .= "<?p " . LJ::html_submit('View Messages(s)') . " p?>";
    $ret .= "</form>";

    $ret .= "<hr style='clear: both;' />";

    $ret .= $class->start_form;

    my @this_months_messages = LJ::SiteMessages->get_all_messages_for_month($year, $month);
    return $ret . "<?p No messages started during the selected month. p?>" unless @this_months_messages;
    $ret .= "</div>";

    $ret .= "<div class='b-adminpage b-adminpage-max b-adminpage-padding'><table>";
    $ret .= "<tr><th>Message</th><th>Countries</th><th>Account type</th><th>Start Date</th><th>End Date</th><th colspan='2'>Active Status</th><th>Edit</th></tr>";
    foreach my $row (@this_months_messages) {
        my $start_date = DateTime->from_epoch( epoch => $row->{time_start}, time_zone => 'America/Los_Angeles' );
        my $end_date = DateTime->from_epoch( epoch => $row->{time_end}, time_zone => 'America/Los_Angeles' );

        $ret .= "<tr>";
        $ret .= "<td>$row->{text}</td>";
        $ret .= "<td>$row->{countries}</td>";
        $ret .= "<td>" . LJ::SiteMessages->get_class_string($row->{accounts}) . "</td>";
        $ret .= "<td>" . $start_date->strftime("%F %r %Z")  . "</td>";
        $ret .= "<td>" . $end_date->strftime("%F %r %Z")  . "</td>";
        $ret .= $class->get_active_text($row->{mid}, $row->{active});
        $ret .= "<td>(<a href='$LJ::SITEROOT/admin/sitemessages/add.bml?mid=$row->{mid}'>edit</a>)</td>";
        $ret .= "</tr>";
    }
    $ret .= "</table></div>";

    $ret .= $class->end_form;

    return $ret;
}

sub get_active_text {
    my $class = shift;
    my ($mid, $active) = @_;

    my ($curr_state, $verb) = $active eq 'Y' ? ("active", "inactivate") : ("inactive", "activate");
    my $to_state = $curr_state eq 'active' ? 'inactive' : 'active';
    return "<td>$curr_state</td><td>" . $class->html_submit("chg:$to_state:$mid", $verb) . "</td>";
}

sub handle_post {
    my $class = shift;
    my $post = shift;
    my %opts = @_;

    # find which to activate/inactivate
    # do the action
    my ($state, $mid);
    while (my ($k, $v) = each %$post) {
        next unless $k =~ /^chg:((?:in)?active):(\w+)/;
        ($state, $mid) = ($1, $2);
        last;
    }

    die "Invalid state for status change"
        unless $state;

    return LJ::SiteMessages->change_active_status($mid, to => $state);
}

1;
