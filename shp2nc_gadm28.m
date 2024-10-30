%Convert GADM (version 2.8) shp file to mask in .nc
%Written by JingXiang CHUNG on 27/2/2019, updated on 30/10/2024
%Reference: https://www.mathworks.com/help/map/vector-to-raster-data-conversion.html
%Need to have Mapping Toolbox and snctools for MATLAB
%
%Usage:
%shp2nc_gadm28(<'shpfile you want to convert'>,<grid per degree lon and lat>);
%
%Example:
%
%shp2nc_gadm28('C:\Users\Jing Xiang\Documents\My_Works\Research\Maps\Shapefile\GADM\Malaysia\MYS_adm0.shp',50)


function shp2nc_gadm28(varargin)

    if nargin < 1; help shp2nc_gadm28; return; end

    shpfile=varargin{1};
    gridRes=varargin{2};

    if isempty(ls(shpfile)); error('Error:file404',['Shpfile specified: ',shpfile,' not found!']); end
    if ~isnumeric(gridRes); error('Error:NaN','Resolution wanted must be a positive number'); end

    gridDensity=round(1/gridRes);
    
    % shpfile='C:\Users\Jing Xiang\Documents\My_Works\Research\Maps\Shapefile\GADM\Malaysia\MYS_adm0.shp';
    % gridDensity=50; %Number of grids wanted for a degree
    
    %--------------------------------------------------------------------------------------
    
    %Import shapefile
    shpraw=shaperead(shpfile);
    
    %Determining number of polygons
    polynum=length(shpraw);
    
    %Determine GADM shp category (0, 1 or 2) from .shp file name
    cat=shpfile(end-4);
    
    %Convert each polygons to separated masks
    for p=1:polynum
    
        shp=shpraw(p);
        if strcmpi(cat,'0')
            polname=shpraw.NAME_ENGLI; 
        else
            polname=eval(['shp.NAME_',cat]); 
        end
        
        statename=strrep(polname,' ','_');
        ncname=([statename,'_mask.nc']);
    
        inLat=shp.Y; %Obtain latitude info
        inLon=shp.X; %Obtain longitude info
        
        %Create grid from data
        [inGrid, inRefVec] = vec2mtx(inLat, inLon, gridDensity);
        % [latlim, lonlim] = limitm(inGrid, inRefVec);  %obsolete

        latlim = inRefVec.LatitudeLimits;
        lonlim = inRefVec.LongitudeLimits;
    
        inPt = round([1, 1, 3]);
        inGrid3 = encodem(inGrid, inPt,1);
        
        inGrid3(inGrid3<3)=1;  %Making ocean became -99
        inGrid3(inGrid3==3)=-99;   %Making land became 1
    
        %Create lon and lat list
        lon=linspace(lonlim(1),lonlim(2),size(inGrid3,2));
        lat=linspace(latlim(1),latlim(2),size(inGrid3,1));
    
        %Writing out to netCDF
        ncfile=ncname;
        nc_create_empty(ncfile);
    
        %write in global attributes
        nc_attput(ncfile,nc_global,'Created_by',['Jing Xiang CHUNG on ',datestr(clock) ]);
        nc_attput(ncfile,nc_global,'Based_on','GADM v2.8 shp file');
        nc_attput(ncfile,nc_global,'Title',['Mask for ',polname]);
    
        %write in dimensions
        nc_adddim(ncfile,'lon' ,length(lon ));
        nc_adddim(ncfile,'lat' ,length(lat ));
    
        %write in variable attributes
        %lat
        ncid=1;
        nc(ncid).Name = 'lat';
        nc(ncid).Datatype='single';
        nc(ncid).Dimension={'lat'};
        nc(ncid).Attribute(1) = struct('Name','standard_name','Value','latitude'); 
        nc(ncid).Attribute(2) = struct('Name','units','Value','degrees_north'); 
    
        %lon
        ncid=ncid+1;
        nc(ncid).Name = 'lon'; 
        nc(ncid).Datatype='single';
        nc(ncid).Dimension={'lon'};
        nc(ncid).Attribute(1) = struct('Name','standard_name','Value','longitude');
        nc(ncid).Attribute(2) = struct('Name','units','Value','degrees_east');
    
        %variable
        ncid=ncid+1;
        nc(ncid).Name = 'mask';
        nc(ncid).Datatype='double';
        nc(ncid).Dimension={'lat','lon'};
        nc(ncid).Attribute(1) = struct('Name','standard_name','Value',['Mask for ',polname]);
        nc(ncid).Attribute(2) = struct('Name','units','Value','1 for land wanted, NaN for other places');
        nc(ncid).Attribute(3) = struct('Name','_FillValue','Value',-99);
        nc(ncid).Attribute(4) = struct('Name','missing_value','Value',-99);
    
        %fill in the variables with the attributes
        for ncid=1:length(nc)
            nc_addvar(ncfile,nc(ncid));
        end
    
        %fill variable
        nc_varput( ncfile, 'lat'     , single(lat)  );
        nc_varput( ncfile, 'lon'     , single(lon)  );
        nc_varput( ncfile, 'mask'    , double(inGrid3) );
    
    end
    
    disp('Job Completed!')
end