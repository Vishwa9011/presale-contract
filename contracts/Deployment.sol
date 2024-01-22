// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "./Presale.sol";

contract Deployment  {
    constructor() {
        // constructor can stay empty
    }

    function deployContract(
        Presale.PresaleInfo memory _presaleInfo,
        Presale.Pool memory _pool,
        Presale.Links memory _links,
        address _presaleList
    ) public returns (Presale) {
        Presale presale = new Presale(_presaleInfo, _pool, _links, _presaleList);
        presale.transferOwnership(msg.sender);
        return presale;
    }
}
 