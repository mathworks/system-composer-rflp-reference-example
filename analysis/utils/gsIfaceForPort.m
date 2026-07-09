function ifn = gsIfaceForPort(pn)
%GSIFACEFORPORT Map a physical-layer port name to its interface name.
%   Naming convention shared by all three physical variant models.

if startsWith(pn, 'status')
    ifn = 'StatusBus';
elseif contains(pn, 'irective')  % directive / transportDirective / productionDirective
    ifn = 'ControlBus';
elseif any(strcmp(pn, {'inboundCargo','receivedIngredients','inboundSupplies'})) || startsWith(pn, 'staged')
    ifn = 'IngredientPallet';
elseif startsWith(pn, 'preppedBatch')
    ifn = 'PreparedBatch';
elseif startsWith(pn, 'cookedSoup') || strcmp(pn, 'approvedSoup')
    ifn = 'SoupStream';
elseif any(strcmp(pn, {'sealedContainers','loadedShipment','outboundShipments'})) || startsWith(pn, 'containers')
    ifn = 'SealedContainerBatch';
elseif strcmp(pn, 'manifest')
    ifn = 'ShippingManifestMsg';
elseif any(strcmp(pn, {'inventoryStatus','reorderRequest'})) || startsWith(pn, 'stock')
    ifn = 'StockData';
elseif strcmp(pn, 'customerOrders')
    ifn = 'OrderPacket';
elseif any(strcmp(pn, {'ambientGravity','envStatus'}))
    ifn = 'GravityData';
else
    ifn = 'StatusBus';
end
end
