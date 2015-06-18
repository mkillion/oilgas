<cfquery name="qInsert" datasource="gis_webinfo">
    insert into og_mapper_comments values('#url.layers#', '#url.tools#', '#url.comments#', '#url.occ#', '#CGI.REMOTE_ADDR#', sysdate)
</cfquery>