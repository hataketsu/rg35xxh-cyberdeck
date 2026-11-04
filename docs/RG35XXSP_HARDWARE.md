# Compatibilitat de maquinari RG35XXSP

L'evidència següent prové de les fonts, **no d'una consola connectada**. Totes les funcionalitats físiques estan PENDENTS. No confondre RG35XXSP amb RG34XXSP ni RG SP.

## Arbre de kernel i DTB

Linux **7.0.2**, tar SHA256 `53591a03294527a48ccb0b9e559e922df8a38554745a1206827ca751d2ca7662`, amb ROCKNIX `8e4055f93f868f177ae3e4639c34238de1beb34a`. La recepta del projecte aplica pedaços de `mainline`, `7.0` i H700 i copia els DTS addicionals de `projects/ROCKNIX/devices/H700/linux/dts/`.

Cadena SP: `sun50i-h700-anbernic-rg35xx-sp.dts` → `rg35xx-plus.dts` → `rg35xx-2024.dts` → DTSI H616. El DTS SP està dins de Linux; la variant `sun50i-h700-anbernic-rg35xx-sp-v2-panel.dts` l'afegeix ROCKNIX i inclou el DTS SP.

| Element | Evidència a les fonts | Port / prova pendent |
|---|---|---|
| Arrencada | U-Boot v2025.07-rc3, H700 LPDDR4, ATF 2.12.0; SPL @8 KiB i MBR | Mateix bootloader H700; memòria i boot real PENDENTS |
| Pantalla estàndard | Compatible heretat `anbernic,rg35xx-plus-panel`, `panel-mipi-dpi-spi` | `PANEL=standard`; 640×480 natiu, sense modelines inventades |
| Pantalla v2 | `anbernic,rg35xx-sp-v2-panel`, `panel-mipi-dpi-spi` | `PANEL=v2`; no és el `rev6` de la H |
| Firmware panell | `extra-firmware/panels/*.panel`, incorporat per recepta Linux H700 | Es conserva al kernel i també al rootfs |
| Retroil·luminació | Pedaç PWM H700 `0010`, nodes backlight/panel | brightnessctl i XFCE; rang real PENDENT |
| PMIC | AXP717, reguladors, ADC, carregador i bateria activats al config | No s'alteren tensions ni límits de càrrega |
| Bateria | `simple-battery` heretada; `axp20x_battery`, nom `battery` via pedaç 0124 | Mesurar capacity/status/voltage_now; càrrega i percentatge PENDENTS |
| Wi-Fi | RTL8821CS SDIO, `RTW88_8821CS=y`; firmware rtw88 | NetworkManager; estabilitat i estalvi PENDENTS |
| Bluetooth | UART1 amb RTS/CTS, compatible RTL8821CS, HCIUART/RTL | BlueZ i Blueman; teclat BLE i node PENDENTS |
| Botons | Pedaç 0140 substitueix gpio-keys pel `rocknix-singleadc-joypad` | Mòdul fixat i construït amb el mateix toolchain/kernel |
| Tapa | `gpio-keys-lid`, PE7 actiu baix, `EV_SW/SW_LID`, wakeup-source | `evtest` pendent; accions de tapa i suspensió desactivades |
| Àudio | SUN4I codec, amplifier heretat; pedaços H700, HDMI separat | PulseAudio/ALSA; altaveu, auriculars i volum PENDENTS |
| USB-C | `dr_mode=otg`; pedaços 0151/0152, detecció ID PI4 i VBUS PI16/boost | Sense gadget; cable OTG i VBUS real PENDENTS |
| Teclat USB | USB HID/libinput | No el captura sp-gamepad; enumeració pendent |
| Heltec sèrie | USB_ACM, CP210X, CH341 habilitats en reconstrucció | No es pressuposa quin pont/nom de port presenta el V4 |

Fonts: [DTS SP de Linux 7.0.2](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tree/arch/arm64/boot/dts/allwinner/sun50i-h700-anbernic-rg35xx-sp.dts?h=v7.0.2), [DTS addicionals ROCKNIX](https://github.com/ROCKNIX/distribution/tree/8e4055f93f868f177ae3e4639c34238de1beb34a/projects/ROCKNIX/devices/H700/linux/dts/allwinner), [pedaços H700](https://github.com/ROCKNIX/distribution/tree/8e4055f93f868f177ae3e4639c34238de1beb34a/projects/ROCKNIX/devices/H700/patches/linux), [fitxa SP ROCKNIX](https://rocknix.org/devices/anbernic/rg35xx-sp/).

No es trasllada a la SP la descripció de «dos ports USB» de la H. Tampoc s'activa forçadament mode host ni es manipula VBUS des d'un script. Un adaptador OTG compatible ha de provocar el canvi de rol previst pel DTS; això encara s'ha de mesurar.

## Identificació segura del panell

ROCKNIX documenta dues variants SP: [guia H700](https://rocknix.org/configure/h700-installation/). No hi ha detecció automàtica fiable implementada. L'aspecte exterior o color de carcassa no és suficient per escollir-les.

1. Conserveu intacta la microSD original. Si es disposa d'una còpia del DTB original o registres de la consola, examineu-ne `model`, `compatible` i panell com a pista; els noms del kernel del fabricant poden ser diferents.
2. Compileu primer `PANEL=standard PROFILE=minimal` i utilitzeu una microSD nova. Les fonts estándar estan disponibles; això no prova que siguin la revisió de la vostra unitat.
3. Si només apareixen ratlles, colors incorrectes o pantalla en blanc, apagueu abans de manipular la SD. Si el sistema respon, preferiu apagada ordenada; la pulsació llarga és recurs final amb possible pèrdua de dades a la SD de proves.
4. Proveu una imatge separada `PANEL=v2`, sense tocar voltatges, PMIC ni cablejat. No cal obrir la consola per al procediment de prova.
5. No copieu DTB de stock, ROCKNIX actual o una altra versió de kernel al port. Aquí no es renomena a `dtb.img`: el boot.scr generat carrega el nom explícit de la variant.

## Validació feta

S'han aplicat 29 fitxers de pedaços de la revisió fixada a Linux 7.0.2 i s'han preprocessat/compilat SP, SP v2, H i H rev6 amb gcc + dtc 1.6.1. Els quatre binaris són llegibles i tenen el compatible correcte. SP també supera les comprovacions de node de tapa i USB OTG. Evidències a `docs/evidence/`; fitxers compilats a `work/dts-audit/`.

Hi ha 11 avisos dtc per variant (14 línies): noms/adreces de bus, proveïdors d'interrupció i nodes del graf de pantalla, inclosos nodes HDMI. Alguns pedaços s'apliquen amb offset/fuzz. No s'han silenciat ni reinterpretat com a validació dt-schema. No s'ha executat `dtbs_check` amb esquemes ni una compilació completa del kernel.

El pedaç original que manté set reguladors sempre encesos **no s'aplica a SP**: falta evidència física que sigui necessari i podria augmentar consum o interferir amb energia. Si la pantalla falla després de ~30 segons, recolliu logs abans de canviar reguladors; aquest punt pot impedir l'arrencada útil i resta pendent.

## Validació posterior: HDMI

El 2026-11-04 l'usuari confirma sortida de vídeo HDMI funcional amb el sistema LPDDR3/SP v2 i XFCE actual, sense necessitat d'executar la comanda de diagnòstic o canviar la configuració. [Evidència](evidence/hdmi-first-output.txt). Resolució/refresc exactes i estabilitat amb reconnexions continuen pendents. L’usuari ha exclòs expressament l’àudio HDMI de l’abast.

## Validació posterior: altaveu intern

El 2026-11-04 es confirma per escolta de l'usuari la reproducció de Front_Center.wav via PulseAudio al codec H616. Els nivells inicials DAC/Line Out combinaven aproximadament 42 dB d'atenuació i la primera prova no era audible. Amb DAC 63 (0 dB) i Line Out 23 (-12 dB) la prova és audible; el volum normal PulseAudio es deixa al 50%. [Registre](evidence/audio-speaker-check.txt). La persistència després de reiniciar i els auriculars resten pendents; aquests valors encara no s'imposen a totes les futures imatges o sortides.
