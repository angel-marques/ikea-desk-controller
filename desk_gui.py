#!/usr/bin/env python3
"""
IKEA IDÅSEN Desk Controller - GUI
Modern graphical interface using customtkinter
"""

import asyncio
import struct
import threading
from pathlib import Path
import customtkinter as ctk
from tkinter import messagebox
from PIL import Image, ImageTk

from idasen_controller import (
    IdasenDesk,
    load_config,
    load_presets,
    MIN_HEIGHT,
    MAX_HEIGHT,
)

# Icon path
ICON_PATH = Path(__file__).parent / "icon.png"


# Dark theme
ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")


class DeskGUI(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("IKEA Desk Controller")
        self.geometry("320x580")
        self.resizable(False, False)

        # Set icon
        if ICON_PATH.exists():
            try:
                icon_image = Image.open(ICON_PATH)
                self.icon_photo = ImageTk.PhotoImage(icon_image)
                self.iconphoto(True, self.icon_photo)
            except Exception:
                pass

        # State
        self.desk = None
        self.connected = False
        self.running = True
        self.moving = False
        self.loop = None
        self.async_thread = None

        # Load config
        self.config = load_config()
        self.presets = load_presets()
        self.addr = self.config.get("addr")

        if not self.addr:
            messagebox.showerror("Error", "No desk configured.\nRun 'desk scan' and 'desk config' first.")
            self.destroy()
            return

        self.setup_ui()
        self.start_async_loop()

        # Connect on start
        self.after(100, self.connect)

        # Handle window close
        self.protocol("WM_DELETE_WINDOW", self.on_close)

    def setup_ui(self):
        # Main container
        self.main_frame = ctk.CTkFrame(self, fg_color="transparent")
        self.main_frame.pack(fill="both", expand=True, padx=20, pady=20)

        # Height display
        self.height_label = ctk.CTkLabel(
            self.main_frame,
            text="--.-",
            font=ctk.CTkFont(size=72, weight="bold")
        )
        self.height_label.pack(pady=(0, 0))

        self.unit_label = ctk.CTkLabel(
            self.main_frame,
            text="cm",
            font=ctk.CTkFont(size=20),
            text_color="gray"
        )
        self.unit_label.pack(pady=(0, 5))

        # Status
        self.status_label = ctk.CTkLabel(
            self.main_frame,
            text="Connecting...",
            font=ctk.CTkFont(size=12),
            text_color="gray"
        )
        self.status_label.pack(pady=(0, 15))

        # STOP button (prominent, always visible)
        self.stop_btn = ctk.CTkButton(
            self.main_frame,
            text="⏹ STOP",
            font=ctk.CTkFont(size=16, weight="bold"),
            fg_color="#c0392b",
            hover_color="#e74c3c",
            height=45,
            command=self.emergency_stop
        )
        self.stop_btn.pack(fill="x", pady=(0, 15))

        # System positions frame
        sys_label = ctk.CTkLabel(
            self.main_frame,
            text="Positions",
            font=ctk.CTkFont(size=12),
            text_color="gray"
        )
        sys_label.pack(anchor="w")

        sys_frame = ctk.CTkFrame(self.main_frame, fg_color="transparent")
        sys_frame.pack(fill="x", pady=(5, 10))

        positions = [
            ("Sit", self.config.get("sit_height", 0.72)),
            ("Stand", self.config.get("stand_height", 1.10)),
            ("Walk", self.config.get("walk_height", 1.18)),
        ]

        for i, (name, height) in enumerate(positions):
            btn = ctk.CTkButton(
                sys_frame,
                text=f"{name}\n{height*100:.0f}cm",
                font=ctk.CTkFont(size=13),
                height=50,
                command=lambda h=height: self.move_to(h)
            )
            btn.grid(row=0, column=i, padx=(0 if i == 0 else 5, 0), sticky="ew")
            sys_frame.columnconfigure(i, weight=1)

        # Custom presets
        if self.presets:
            preset_label = ctk.CTkLabel(
                self.main_frame,
                text="Presets",
                font=ctk.CTkFont(size=12),
                text_color="gray"
            )
            preset_label.pack(anchor="w", pady=(10, 0))

            preset_frame = ctk.CTkFrame(self.main_frame, fg_color="transparent")
            preset_frame.pack(fill="x", pady=(5, 10))

            sorted_presets = sorted(self.presets.items())
            for i, (name, height) in enumerate(sorted_presets):
                btn = ctk.CTkButton(
                    preset_frame,
                    text=f"{name}\n{height*100:.0f}cm",
                    font=ctk.CTkFont(size=13),
                    fg_color="#2d5a27",
                    hover_color="#3d7a37",
                    height=50,
                    command=lambda h=height: self.move_to(h)
                )
                btn.grid(row=0, column=i, padx=(0 if i == 0 else 5, 0), sticky="ew")
                preset_frame.columnconfigure(i, weight=1)

        # Manual controls
        ctrl_label = ctk.CTkLabel(
            self.main_frame,
            text="Manual",
            font=ctk.CTkFont(size=12),
            text_color="gray"
        )
        ctrl_label.pack(anchor="w", pady=(10, 0))

        ctrl_frame = ctk.CTkFrame(self.main_frame, fg_color="transparent")
        ctrl_frame.pack(fill="x", pady=(5, 0))

        self.up_btn = ctk.CTkButton(
            ctrl_frame,
            text="▲ Up",
            font=ctk.CTkFont(size=14),
            fg_color="#555555",
            hover_color="#666666",
            height=45,
            command=self.move_up
        )
        self.up_btn.grid(row=0, column=0, padx=(0, 5), sticky="ew")

        self.down_btn = ctk.CTkButton(
            ctrl_frame,
            text="▼ Down",
            font=ctk.CTkFont(size=14),
            fg_color="#555555",
            hover_color="#666666",
            height=45,
            command=self.move_down
        )
        self.down_btn.grid(row=0, column=1, sticky="ew")

        ctrl_frame.columnconfigure(0, weight=1)
        ctrl_frame.columnconfigure(1, weight=1)

    def start_async_loop(self):
        """Start asyncio event loop in background thread."""
        def run_loop():
            self.loop = asyncio.new_event_loop()
            asyncio.set_event_loop(self.loop)
            self.loop.run_forever()

        self.async_thread = threading.Thread(target=run_loop, daemon=True)
        self.async_thread.start()

    def run_async(self, coro):
        """Run coroutine in the async thread."""
        if self.loop and self.loop.is_running():
            return asyncio.run_coroutine_threadsafe(coro, self.loop)
        return None

    def connect(self):
        """Connect to the desk."""
        self.run_async(self._connect())

    async def _connect(self):
        try:
            self.desk = IdasenDesk(self.addr)
            if await self.desk.connect():
                self.connected = True
                self.update_status("Connected")
                # Start monitoring
                asyncio.create_task(self._monitor())
            else:
                self.update_status("Connection failed - retrying...")
                await asyncio.sleep(2)
                if self.running:
                    await self._connect()
        except Exception as e:
            self.update_status(f"Error: {str(e)[:30]}")
            await asyncio.sleep(2)
            if self.running:
                await self._connect()

    async def _monitor(self):
        """Monitor height continuously."""
        error_count = 0
        while self.running:
            # Skip monitoring while moving to avoid BLE conflicts
            if self.moving:
                await asyncio.sleep(0.3)
                continue

            try:
                if self.connected and self.desk and self.desk.client and self.desk.client.is_connected:
                    height = await self.desk.get_height()
                    self.after(0, lambda h=height: self.update_height(h))
                    error_count = 0  # Reset on success
                elif not self.connected and self.running:
                    # Wait for reconnection
                    await asyncio.sleep(1)
                    continue
            except Exception as e:
                error_count += 1
                if error_count > 5:
                    # Connection likely lost, try to reconnect
                    self.connected = False
                    self.update_status("Reconnecting...")
                    await asyncio.sleep(2)
                    if self.running:
                        asyncio.create_task(self._connect())
                    return
            await asyncio.sleep(0.5)

    def update_height(self, height):
        """Update height display."""
        cm = height * 100
        self.height_label.configure(text=f"{cm:.1f}")

    def update_status(self, text):
        """Update status label."""
        self.after(0, lambda: self.status_label.configure(text=text))

    def emergency_stop(self):
        """Emergency stop - immediately halt desk movement."""
        self.moving = False
        self.update_status("STOPPING...")
        self.run_async(self._emergency_stop())

    async def _emergency_stop(self):
        """Send stop command multiple times to ensure it stops."""
        try:
            if self.desk and self.desk.client and self.desk.client.is_connected:
                # Send stop multiple times
                for _ in range(3):
                    await self.desk.stop()
                    await asyncio.sleep(0.1)
                self.update_status("Stopped")
        except Exception as e:
            self.update_status(f"Stop error: {str(e)[:20]}")

    def move_to(self, height):
        """Move desk to specified height."""
        if self.moving:
            return
        self.moving = True
        self.update_status(f"Moving to {height*100:.0f}cm...")
        self.run_async(self._move_to(height))

    async def _move_to(self, target_height):
        try:
            if self.desk and self.desk.client and self.desk.client.is_connected:
                # Custom move loop that updates GUI
                target_height = max(0.62, min(1.27, target_height))

                # Stop notifications
                if self.desk._notifications_started:
                    try:
                        await self.desk.client.stop_notify("99fa0021-338a-1024-8a49-009c0215f78a")
                        self.desk._notifications_started = False
                    except Exception:
                        pass

                current = await self.desk.get_height()
                self.after(0, lambda h=current: self.update_height(h))

                if abs(current - target_height) < 0.005:
                    self.update_status("Connected")
                    return

                # Convert target to bytes
                raw_target = int((target_height - 0.62) * 10000)
                target_bytes = struct.pack("<H", raw_target)

                # Initialize
                await self.desk.client.write_gatt_char("99fa0002-338a-1024-8a49-009c0215f78a", bytearray([0xFE, 0x00]))
                await asyncio.sleep(0.1)
                await self.desk.client.write_gatt_char("99fa0002-338a-1024-8a49-009c0215f78a", bytearray([0xFF, 0x00]))
                await asyncio.sleep(0.1)

                previous_height = current
                stall_count = 0

                while self.moving:  # Can be stopped by STOP button
                    await self.desk.client.write_gatt_char("99fa0031-338a-1024-8a49-009c0215f78a", target_bytes)
                    await asyncio.sleep(0.2)

                    current = await self.desk.get_height()
                    self.after(0, lambda h=current: self.update_height(h))

                    if abs(current - target_height) < 0.01:
                        break

                    if abs(current - previous_height) < 0.001:
                        stall_count += 1
                        if stall_count > 20:
                            break
                    else:
                        stall_count = 0

                    previous_height = current

                await self.desk.stop()
                self.update_status("Connected")

        except Exception as e:
            self.update_status(f"Error: {str(e)[:25]}")
            if self.desk and self.desk.client:
                try:
                    if not self.desk.client.is_connected:
                        self.connected = False
                        asyncio.create_task(self._connect())
                except Exception:
                    pass
        finally:
            self.moving = False

    def move_up(self):
        """Move desk up."""
        self.run_async(self._move_up())

    async def _move_up(self):
        try:
            if self.desk and self.desk.client and self.desk.client.is_connected:
                await self.desk.move_up()
        except Exception:
            pass

    def move_down(self):
        """Move desk down."""
        self.run_async(self._move_down())

    async def _move_down(self):
        try:
            if self.desk and self.desk.client and self.desk.client.is_connected:
                await self.desk.move_down()
        except Exception:
            pass

    def on_close(self):
        """Handle window close."""
        self.running = False
        self.connected = False

        async def cleanup():
            if self.desk:
                try:
                    await self.desk.disconnect()
                except Exception:
                    pass

        if self.loop and self.loop.is_running():
            future = asyncio.run_coroutine_threadsafe(cleanup(), self.loop)
            try:
                future.result(timeout=1)
            except Exception:
                pass
            self.loop.call_soon_threadsafe(self.loop.stop)

        self.destroy()


def main():
    app = DeskGUI()
    app.mainloop()


if __name__ == "__main__":
    main()
