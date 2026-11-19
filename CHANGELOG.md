# Historial de cambios

## 1.1 — 2026-11-19

Primera versión que funciona de principio a fin con el pincho `33fa:0001`
(USB2.0-BT, Barrot BR8554) en Linux.

Arreglos sobre el port inicial:

- **EP0 sin `wLength`**: los comandos HCI salían con longitud 0. Ahora la
  cabecera H:2 se envía completa.
- **Doble `usb_free_urb()`**: bajoflujo de referencias y uso tras liberar.
- **`skb->dev` sin asignar**: no se recuperaba el `hci_dev` al completar un URB.
- **Buffers RX pequeños**: eventos y ACL truncados; ahora
  `HCI_MAX_EVENT_SIZE` (260) y `HCI_MAX_FRAME_SIZE`.
- **`skb_pull(skb, 1)` en el envío**: corrompía la cabecera del comando, del ACL
  y del SCO. El endpoint ya identifica el tipo de paquete, así que ahora se
  envían en crudo.
- **Autosuspensión**: a los ~2 s el pincho se dormía y todo lo enviado después
  se perdía (`tx urb submit failed (-113)`). Se desactiva con
  `supports_autosuspend = 0` y `pm_runtime_forbid()` al arrancar.
- **Parámetros nuevos**: `debug_packets` (volcado de paquetes) y `pm_wakeup`
  (ciclo de suspensión forzado, solo diagnóstico).

Comprobado: conexión con un Redmi Note 12S mantenida más de 40 s, con más de
4000 paquetes ACL recibidos y 0 errores.

## 1.0

Port inicial del driver de Windows «BARROT BRLink» (`brtlinkusb_54.sys`) a
Linux, con el transporte HCI USB y los enganches del fabricante (comando mágico
`EE EE 01 02 03 04 05` y cambio a modo HID).
