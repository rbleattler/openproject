/*
 * -- copyright
 * OpenProject is an open source project management software.
 * Copyright (C) the OpenProject GmbH
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License version 3.
 *
 * OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
 * Copyright (C) 2006-2013 Jean-Philippe Lang
 * Copyright (C) 2010-2013 the ChiliProject Team
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 *
 * See COPYRIGHT and LICENSE files for more details.
 * ++
 */

export type OpTheme = 'light' | 'light_high_contrast' | 'dark' | 'dark_high_contrast';

export class ThemeUtils {
  public applySystemThemeImmediately():void {
    const theme = this.detectSystemTheme();
    this.applyThemeToBody(theme);
  }

  public detectSystemTheme():OpTheme {
    return this.prefersSystemLightMode() ? 'light' : 'dark';
  }

  public prefersSystemLightHighContrast():boolean {
    return this.prefersSystemLightMode() && this.prefersSystemHighContrast();
  }

  public prefersSystemLightMode():boolean {
    return window.matchMedia('(prefers-color-scheme: light)').matches;
  }

  public prefersSystemHighContrast():boolean {
    return window.matchMedia('(prefers-contrast: more)').matches;
  }

  public applyThemeToBody(theme:OpTheme):void {
    const increaseContrast = this.prefersSystemHighContrast();
    const body = document.body;

    switch (theme) {
      case 'dark':
        body.setAttribute('data-color-mode', 'dark');
        body.setAttribute('data-dark-theme', increaseContrast ? 'dark_high_contrast' : 'dark');
        body.removeAttribute('data-light-theme');
        break;
      case 'light':
        body.setAttribute('data-color-mode', 'light');
        body.setAttribute('data-light-theme', increaseContrast ? 'light_high_contrast' : 'light');
        body.removeAttribute('data-dark-theme');
        break;
      default: // Do nothing
        break;
    }
  }
}
