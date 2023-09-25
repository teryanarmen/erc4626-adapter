// SPDX-License-Identifier: GPL-3.0-or-later
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity ^0.8.0;

import '@mimic-fi/v3-helpers/contracts/math/FixedPoint.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol';
import './interfaces/IERC4626Adapter.sol';

contract ERC4626Adapter is ERC4626, IERC4626Adapter {
    using FixedPoint for uint256;

    IERC4626 private immutable _erc4626;
    uint256 private immutable _fee; //TODO: must be posible to reduce it
    address private immutable _feeCollector; //TODO: must be posible to change it

    uint256 private _totalInvested;

    constructor(
        IERC4626 erc4626_,
        uint256 fee_,
        address feeCollector_
    ) 
    ERC20( IERC20Metadata(erc4626_.asset()).symbol(), IERC20Metadata(erc4626_.asset()).name())
    ERC4626(IERC20Metadata(erc4626_.asset()))  {
        _erc4626 = erc4626_;
        _fee = fee_;
        _feeCollector = feeCollector_;
    }

    function totalInvested() public view returns (uint256) {
        return _totalInvested;
    }

    function totalAssets() public view override(IERC4626, ERC4626)  returns (uint256) {
        return _erc4626.totalAssets();
    }

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        _settleFees();

        super._deposit( caller,  receiver,  assets,  shares);

        IERC20(_erc4626.asset()).approve(address(_erc4626), assets);
        _erc4626.deposit(assets, address(this));

        _totalInvested = _erc4626.totalAssets();
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        _settleFees();

        _erc4626.withdraw(assets, address(this), address(this));

        super._withdraw( caller,  receiver, owner, assets,  shares);

        _totalInvested = _erc4626.totalAssets();
    }

    function balanceOf(address account) public view override(IERC20, ERC20) returns (uint256) {
        if(account == _feeCollector) {
           return  super.balanceOf(account) + _pendingSharesFeeToCharge();
        }
        return super.balanceOf(account);
    }

    function totalSupply() public view override(IERC20, ERC20) returns (uint256) {
        return super.totalSupply() + _pendingSharesFeeToCharge();
    }

    function _pendingSharesFeeToCharge() private view returns (uint256) {
        if( _erc4626.totalAssets()  == 0 || _totalInvested == 0) return 0;
        uint256 pendingAssetsFeeToCharge = (_erc4626.totalAssets() - _totalInvested).mulUp(_fee);
        uint256 prevShareValue = (_erc4626.totalAssets() - pendingAssetsFeeToCharge).divDown(super.totalSupply());
        return pendingAssetsFeeToCharge.divUp(prevShareValue);
    }

    function _settleFees() private {
         _mint(_feeCollector, _pendingSharesFeeToCharge());
    }

}