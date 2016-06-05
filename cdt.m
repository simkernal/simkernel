function [X,T]=cdt(xb, xi, nTri, keepBoundary, arg)

if nargin<2 || isempty(xi), xi = zeros(0, 2); end
if nargin<4, keepBoundary = false; end

if ~isreal(xb), xb = [real(xb) imag(xb)]; end
assert( size(xb, 2)==2, 'b is not a matrix with 2 columns, transposed?' );

triangle = which('triangle.ex_');
assert(~isempty(triangle), 'Can''t find triangle application');

filename = tempname;
writePoly([filename '.poly'], xb, xi);


if nargin<5
    if nargin<3 || nTri<=0
        averArea = 0;
    else
        if ~iscell(xb)
            averArea = polyarea(xb(:,1)', xb(:,2)', 2)/nTri;
        else
            averArea = abs( sum(cellfun(@signedpolyarea, xb))/nTri );
        end
    end

    %%
    % -Y Prohibits the insertion of Steiner points on the mesh boundary
    % -c including convex hull into the triangulation, 
    % -q50 for specifying min angle
    arg = ' -g ';
    if keepBoundary, arg = [arg '-Y ']; end
    % use num2str(..., '%f') to fix a bug of not getting target # triangles
    if averArea>0, arg = [arg '-a' num2str(averArea, '%f') ' ']; end
    evalc(['!"' triangle '" -q30' arg filename '.poly']); 
%     eval(['!"' triangle '" -c -q50 -g -Y ' filename '.poly']);
else % use input arg
    evalc(['!"' triangle '" -g' arg ' ' filename '.poly']); 
end

%%
[X, T] = loadOff( [filename '.1.off'] );
X = X(:, 1:2);

eval( ['delete ' filename '.poly'] );
eval( ['delete ' filename '.1.node'] );
eval( ['delete ' filename '.1.ele'] );
eval( ['delete ' filename '.1.poly'] );
eval( ['delete ' filename '.1.off'] );


%% important for some mesh processing. Not clear why Triangle produce these isolated vertices
if ~all( sparse(1, T, 1, 1, size(X,1)) )
    nv0 = size(X, 1);
    [X, T] = removeIsolatedVerticesInMesh(X, T);
    warning('%d isolated vertices produced by Triangle have been removed', nv0-size(X,1));
end



function [X, T] = loadOff(filename)

%%
[fid, errmsg] = fopen(filename,'r');
if fid == -1
    warning(errmsg);
    return;
end

%%
str = textscan(fid, '%s', 1, 'CommentStyle', '#');
if ~strcmp(str{1}, 'OFF')
    return;
end

str = textscan(fid, '%d %d %d', 1, 'CommentStyle', '#');
nv = str{1};
nf = str{2};

%%
X = cell2mat( textscan(fid, '%f %f %f', nv, 'CommentStyle', '#') );

%%
pos = ftell(fid);
tsz = textscan(fid, '%f %*[^\n]', nf, 'CommentStyle', '#');
fseek(fid, pos, 'bof');

%%
if all(tsz{1}==3)
    T = cell2mat( textscan(fid, '%*f %f %f %f', nf, 'CommentStyle', '#') ) + 1;
else
    T = cell(nf, 1);
    for i=1:nf
        str = textscan(fid, '%f', 1, 'CommentStyle', '#');
        str = textscan(fid, '%f', str{1}, 'CommentStyle', '#');

        T{i} = reshape(str{1}, 1, []) + 1;
    end
end

%%
fclose(fid);


function writePoly(filename, xb, xi, edges)

if nargin<3
    xi = zeros(0, 2);
end

if nargin<4
    edges = zeros(0, 2);
end

[fid,errmsg] = fopen(filename,'wt');
if fid == -1
    disp(errmsg);
    return;
end

if iscell(xb)
    holes = xb(2:end);
    xb = xb{1};
else
    holes = {};
end

nH = numel(holes);
nb = size(xb,1);
nhv = sum( cellfun(@length, holes) );
nv = size(xi,1) + nb + nhv;

%% vertices
fprintf(fid, '%d 2 0 0\n', nv);
fprintf(fid, '%d %.8f %.8f\n', [1:nv; xb(:,1:2)' xi(:,1:2)' cat(1,holes{:})'] );

%% edges
nie = size(edges,1);
fprintf(fid, '%d 0\n', nb+nie+nhv);

fGenPolyEdges = @(n) [1:n; 2:n 1];

e = [fGenPolyEdges(nb) edges'+nb];
for i=1:nH
    n = nv - sum( cellfun(@length, holes(i:end)) );
    e = [e fGenPolyEdges(size(holes{i}, 1 ))+n];
end

fprintf(fid, '%d %d %d\n', [1:size(e,2); e] );
% fprintf(fid, '%d %d %d\n', [1:nb; 1:nb; [2:nb 1]] );
% fprintf(fid, '%d %d %d\n', [(1:nie)+nb; edges'] );

%% holes
fprintf(fid, '%d\n', nH);
fprintf(fid, '%d %.8f %.8f\n', [1:nH; cell2mat( cellfun( @findPointInPolygon, holes, 'UniformOutput', false ) )'] );

fclose(fid);

function x = findPointInPolygon(p)

poly2area = @(x) sum( x(:,1).*x([2:end 1],2) - x([2:end 1],1).*x(:,2) );

n = size(p,1);
k = nchoosek(1:n, 3);
a = poly2area(p);
for i=1:size(k,1)
    tri = p(k(i,:),:);
    x = sum(tri)/3;
    
    if poly2area(tri)/a > 1e-4 && inpolygon(x(1), x(2), p(:,1), p(:,2))
        break;
    end
end


